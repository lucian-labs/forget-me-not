import AVFoundation
import CoreAudio
import Foundation

/// Everything the synth needs to voice an alert — mirrors the web app's sound settings
/// (`src/sounds.ts`): the global seed flavors EVERY jingle (web: YamaBruh's constructor
/// seed), preset picks the FM patch, mode picks the scale, plus bpm + volume.
struct SoundConfig: Equatable {
    var enabled: Bool
    var seed: String
    var preset: Int
    var bpm: Double
    var volume: Double
    var mode: Int
}

/// The real deal: jingles voiced by the vendored PocketWave FM synth ("yama-bruh") — the
/// same instrument behind the web app's YamaBruh sounds, so the 99 presets line up with
/// the web's preset numbers. Swift stays the melody brain (seeded walk with real note
/// lengths + rests); the C synth supplies voices, ADSR envelopes, and release tails.
@MainActor
final class SynthEngine {
    private let engine = AVAudioEngine()
    private let box = JingleBox()
    private var started = false

    static var presetCount: Int { Int(NUM_PRESETS) }
    static func presetName(_ idx: Int) -> String { String(cString: pw_preset_name(Int32(idx))) }

    /// Compose + schedule one jingle. A new play releases the previous one.
    func play(seed: String, config: SoundConfig) {
        guard start() else { return }
        let events = compose(seed: seed, config: config, sampleRate: box.sampleRate)
        box.schedule(events: events, preset: config.preset, gain: Float(min(max(config.volume, 0), 1)))
    }

    private func start() -> Bool {
        if started { return true }
        // .playback + mixWithOthers: audible without pausing the user's music.
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        let sessionRate = AVAudioSession.sharedInstance().sampleRate
        let rate = sessionRate > 0 ? sessionRate : 48_000
        guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2) else { return false }
        box.sampleRate = rate

        let box = self.box
        let node = AVAudioSourceNode(format: format) { _, _, frameCount, audioBuffers in
            box.render(frames: Int(frameCount), into: audioBuffers)
            return noErr
        }
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        do { try engine.start() } catch { return false }
        started = true
        return true
    }

    // MARK: - melody composition (seeded, deterministic)

    /// Scale flavors selectable via `mode` (wraps).
    private static let scales: [[Int]] = [
        [0, 2, 4, 7, 9],           // major pentatonic
        [0, 3, 5, 7, 10],          // minor pentatonic
        [0, 2, 3, 5, 7, 9, 10],    // dorian
        [0, 2, 4, 6, 7, 9, 11],    // lydian
        [0, 1, 3, 5, 7, 8, 10],    // phrygian
        [0, 2, 4, 5, 7, 9, 10],    // mixolydian
        [0, 2, 4, 6, 8, 10],       // whole tone
        [0, 3, 5, 6, 7, 10],       // blues
    ]

    private func compose(seed: String, config: SoundConfig, sampleRate: Double) -> [JingleEvent] {
        // Full jingle identity = global seed | task seed | preset. Same trio, same tune,
        // forever — and changing the global seed re-rolls the whole soundscape at once.
        var rng = JingleRNG(seed: "\(config.seed)|\(seed)|\(config.preset)")
        let scale = Self.scales[((config.mode % Self.scales.count) + Self.scales.count) % Self.scales.count]

        let bpm = min(max(config.bpm, 50), 260)
        let eighth = 60.0 / bpm / 2.0
        let noteCount = 5 + Int(rng.next() % 5)           // 5–9 notes
        let root = 52 + Int(rng.next() % 17)              // E3..A4 region

        var events: [JingleEvent] = []
        var t = 0.0
        var degree = Int(rng.next() % UInt64(scale.count))
        var played = 0
        while played < noteCount, t < 4.0 {
            // Real note lengths: weighted eighths/quarters/dotted/half + occasional rest.
            if rng.next() % 6 == 0 { t += eighth; continue }
            let units = [1, 1, 1, 2, 2, 3, 4][Int(rng.next() % 7)]
            let isLast = played == noteCount - 1
            let dur = Double(units) * eighth * (isLast ? 2.0 : 1.0)
            let gate = dur * (isLast ? 1.2 : 0.55 + Double(rng.next() % 41) / 100.0)  // 55–95%

            let octave = Int(floor(Double(degree) / Double(scale.count)))
            let idx = ((degree % scale.count) + scale.count) % scale.count
            let note = Int32(root + octave * 12 + scale[idx])
            var vel = Int32(70 + rng.next() % 50)
            if played == 0 { vel = min(127, vel + 15) }   // accent the opening note

            events.append(JingleEvent(frame: Int(t * sampleRate), on: true, note: note, vel: vel))
            events.append(JingleEvent(frame: Int((t + gate) * sampleRate), on: false, note: note, vel: 0))

            // Walk the scale; occasional octave hop.
            let hop = rng.next() % 8
            if hop == 0 { degree += scale.count }
            else if hop == 1 { degree -= scale.count }
            else { degree += Int(rng.next() % 5) - 2 }
            degree = min(max(degree, -scale.count), scale.count * 2)

            t += dur
            played += 1
        }
        return events.sorted { $0.frame < $1.frame }
    }
}

/// One scheduled note edge, in frames from jingle start.
struct JingleEvent {
    var frame: Int
    var on: Bool
    var note: Int32
    var vel: Int32
}

/// Shared state between the main thread (schedules jingles) and the audio render thread.
/// The FMSynth C state is touched ONLY under the lock; critical sections are tiny.
private final class JingleBox: @unchecked Sendable {
    private let lock = NSLock()
    private let synth: UnsafeMutablePointer<FMSynth>
    private var events: [JingleEvent] = []
    private var cursor = 0
    private var frame = 0
    private var gain: Float = 0.4
    private var scratch = [Float](repeating: 0, count: 4096 * 2)
    var sampleRate: Double = 48_000

    init() {
        synth = UnsafeMutablePointer<FMSynth>.allocate(capacity: 1)
        fm_synth_init(UnsafeMutableRawPointer(synth))
    }

    func schedule(events newEvents: [JingleEvent], preset: Int, gain newGain: Float) {
        lock.lock()
        defer { lock.unlock() }
        // Release anything still ringing from the previous jingle (its offs are dropped).
        for e in events[min(cursor, events.count)...] where e.on { fm_note_off(synth, e.note) }
        let count = Int32(NUM_PRESETS)
        synth.pointee.current_preset = ((Int32(preset) % count) + count) % count
        events = newEvents
        cursor = 0
        frame = 0
        gain = newGain
    }

    /// Audio-thread render: fire due note edges, then let the FM synth fill the block.
    func render(frames: Int, into audioBuffers: UnsafeMutablePointer<AudioBufferList>) {
        lock.lock()
        while cursor < events.count, events[cursor].frame <= frame {
            let e = events[cursor]
            if e.on { fm_note_on(synth, e.note, e.vel) } else { fm_note_off(synth, e.note) }
            cursor += 1
        }
        let n = min(frames, scratch.count / 2)
        scratch.withUnsafeMutableBufferPointer { buf in
            fm_synth_render(UnsafeMutableRawPointer(synth), buf.baseAddress, Int32(n), Int32(sampleRate))
        }
        frame += n
        let g = gain
        lock.unlock()

        let abl = UnsafeMutableAudioBufferListPointer(audioBuffers)
        for ch in 0..<abl.count {
            guard let dst = abl[ch].mData?.assumingMemoryBound(to: Float.self) else { continue }
            let src = min(ch, 1)
            for i in 0..<frames { dst[i] = i < n ? scratch[i * 2 + src] * g : 0 }
        }
    }
}

/// Deterministic splitmix64 seeded from a string (FNV-1a) — same seed, same jingle.
struct JingleRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: String) {
        var h: UInt64 = 0xcbf29ce484222325
        for b in seed.utf8 { h = (h ^ UInt64(b)) &* 0x100000001b3 }
        state = h == 0 ? 0x9e3779b97f4a7c15 : h
    }

    mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }
}
