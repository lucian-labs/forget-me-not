import AVFoundation
import CoreAudio
import Foundation

/// Everything the synth needs to voice an alert — mirrors the web app's sound settings
/// (`src/sounds.ts`): the global seed flavors EVERY jingle (web: YamaBruh's constructor
/// seed), preset picks the FM patch, mode picks the MOOD (0–9), plus bpm + volume.
struct SoundConfig: Equatable {
    var enabled: Bool
    var seed: String
    var preset: Int
    var bpm: Double
    var volume: Double
    var mode: Int
}

/// Jingles voiced by the vendored PocketWave FM synth ("yama-bruh"), with the melody
/// logic ported LINE-FOR-LINE from the web's yamabruh-notify.js `_generateSequence`:
/// same djb2 seed hash, same xorshift RNG (same call order), same 38 scales, same 10
/// moods (curated scale pools, movement tables, beat durations, cadence resolution).
/// That note brain is why the web's tunes felt right — this is it, not an imitation.
@MainActor
final class SynthEngine {
    private let engine = AVAudioEngine()
    private let box = JingleBox()
    private var started = false

    static var presetCount: Int { Int(NUM_PRESETS) }
    static func presetName(_ idx: Int) -> String { String(cString: pw_preset_name(Int32(idx))) }
    static let moodNames = ["Pretty", "Experimental", "Depressing", "Spooky", "Dreamy",
                            "Aggressive", "Exotic", "Jazzy", "Ethereal", "Mechanical"]

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
        // @Sendable: without it the closure inherits this method's @MainActor isolation and
        // the runtime SIGTRAPs (dispatch_assert_queue) when the audio thread calls it.
        let node = AVAudioSourceNode(format: format) { @Sendable _, _, frameCount, audioBuffers in
            box.render(frames: Int(frameCount), into: audioBuffers)
            return noErr
        }
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        do { try engine.start() } catch { return false }
        started = true
        return true
    }

    // MARK: - melody (port of yamabruh-notify.js)

    /// All scales (semitone intervals within one octave) — web SCALES, same order for
    /// the "all scales" pool so RNG picks line up.
    private static let scaleTable: [(String, [Int])] = [
        ("major", [0, 2, 4, 5, 7, 9, 11]),
        ("dorian", [0, 2, 3, 5, 7, 9, 10]),
        ("phrygian", [0, 1, 3, 5, 7, 8, 10]),
        ("lydian", [0, 2, 4, 6, 7, 9, 11]),
        ("mixolydian", [0, 2, 4, 5, 7, 9, 10]),
        ("aeolian", [0, 2, 3, 5, 7, 8, 10]),
        ("locrian", [0, 1, 3, 5, 6, 8, 10]),
        ("harmonicMinor", [0, 2, 3, 5, 7, 8, 11]),
        ("melodicMinor", [0, 2, 3, 5, 7, 9, 11]),
        ("pentMajor", [0, 2, 4, 7, 9]),
        ("pentMinor", [0, 3, 5, 7, 10]),
        ("blues", [0, 3, 5, 6, 7, 10]),
        ("wholeTone", [0, 2, 4, 6, 8, 10]),
        ("doubleHarmonic", [0, 1, 4, 5, 7, 8, 11]),
        ("hungarianMinor", [0, 2, 3, 6, 7, 8, 11]),
        ("phrygianDom", [0, 1, 4, 5, 7, 8, 10]),
        ("neapolitanMin", [0, 1, 3, 4, 7, 8, 10]),
        ("neapolitanMaj", [0, 1, 3, 5, 7, 9, 11]),
        ("altered", [0, 1, 3, 5, 6, 8, 10]),
        ("prometheus", [0, 2, 4, 6, 9, 10]),
        ("kumoi", [0, 2, 3, 7, 8]),
        ("japanese", [0, 2, 3, 7, 9]),
        ("hirajoshi", [0, 1, 5, 7, 10]),
        ("iwato", [0, 1, 3, 7, 8]),
        ("enigmatic", [0, 1, 3, 6, 7, 9, 10]),
        ("persian", [0, 1, 4, 6, 8, 10, 11]),
        ("arabian", [0, 2, 4, 5, 6, 8, 10]),
        ("pelog", [0, 1, 3, 4, 7, 9, 10]),
        ("gypsy", [0, 2, 3, 6, 7, 8, 10]),
        ("flamenco", [0, 1, 4, 5, 7, 8, 11]),
        ("bebopDom", [0, 2, 4, 5, 7, 9, 10, 11]),
        ("lydianDom", [0, 2, 4, 6, 7, 9, 10]),
        ("bluesMajor", [0, 3, 4, 7, 9, 10]),
        ("dimWH", [0, 2, 3, 5, 6, 8, 9, 11]),
        ("dimHW", [0, 1, 3, 4, 6, 7, 9, 10]),
        ("augmented", [0, 4, 6, 7, 11]),
        ("egyptian", [0, 2, 5, 7, 10]),
        ("balinese", [0, 1, 5, 7, 8]),
        ("bebopMinor", [0, 2, 3, 5, 7, 8, 10, 11]),
    ]
    private static let scaleByName = Dictionary(uniqueKeysWithValues: scaleTable)

    private struct Mood {
        let scales: [String]?      // nil = all scales
        let movements: [Int]       // scale-degree steps, mood-flavored contour
        let durations: [Double]    // note lengths in beats
        let maxNotes: Int          // web noteRange[1]; min is always 2 (web minLength)
        let rootBase: Int
        let rootSpread: Int
        let resolve: Bool          // land the last note on root / 3rd / octave
    }

    /// Web MOODS, indexed 0–9 — pretty, experimental, depressing, spooky, dreamy,
    /// aggressive, exotic, jazzy, ethereal, mechanical.
    private static let moods: [Mood] = [
        Mood(scales: ["pentMajor", "pentMinor", "major", "lydian", "mixolydian"],
             movements: [1, -1, 2, -2, 1, -1, 2, -2, 0, 3, -3],
             durations: [0.25, 0.25, 0.5, 0.5, 1.0],
             maxNotes: 6, rootBase: 60, rootSpread: 3, resolve: true),
        Mood(scales: nil,
             movements: [0, 2, -2, 3, -3, 4, -4, 6, -6],
             durations: [0.125, 0.25, 0.5, 1.0, 2.0],
             maxNotes: 5, rootBase: 54, rootSpread: 3, resolve: false),
        Mood(scales: ["aeolian", "harmonicMinor", "phrygian", "pentMinor", "locrian", "neapolitanMin"],
             movements: [-1, -2, 1, -1, -2, -3, 0, -1, 2],
             durations: [0.5, 0.5, 1.0, 1.0, 2.0],
             maxNotes: 5, rootBase: 48, rootSpread: 2, resolve: false),
        Mood(scales: ["dimWH", "dimHW", "wholeTone", "locrian", "altered", "hungarianMinor", "iwato", "enigmatic"],
             movements: [1, -1, 3, -3, 6, -6, 4, -4, 0],
             durations: [0.25, 0.5, 0.5, 1.0, 0.125],
             maxNotes: 5, rootBase: 48, rootSpread: 4, resolve: false),
        Mood(scales: ["lydian", "pentMajor", "wholeTone", "major", "mixolydian"],
             movements: [1, -1, 2, -2, 0, 1, -1, 3, 2],
             durations: [0.5, 0.5, 1.0, 1.0, 2.0],
             maxNotes: 6, rootBase: 60, rootSpread: 2, resolve: true),
        Mood(scales: ["phrygian", "phrygianDom", "blues", "dimHW", "flamenco", "hungarianMinor"],
             movements: [2, -2, 3, -3, 4, -4, 6, -6, 1],
             durations: [0.125, 0.125, 0.25, 0.25, 0.5],
             maxNotes: 6, rootBase: 42, rootSpread: 3, resolve: false),
        Mood(scales: ["doubleHarmonic", "persian", "arabian", "pelog", "gypsy", "flamenco", "hirajoshi", "kumoi", "japanese", "balinese"],
             movements: [1, -1, 2, -2, 3, -3, 0, 1, 4],
             durations: [0.25, 0.25, 0.5, 0.5, 1.0],
             maxNotes: 5, rootBase: 54, rootSpread: 3, resolve: false),
        Mood(scales: ["dorian", "mixolydian", "lydianDom", "bebopDom", "bebopMinor", "melodicMinor", "bluesMajor", "blues"],
             movements: [1, -1, 2, -2, 3, -3, 4, 0, -4],
             durations: [0.25, 0.25, 0.5, 0.125, 0.5],
             maxNotes: 6, rootBase: 54, rootSpread: 3, resolve: true),
        Mood(scales: ["wholeTone", "pentMajor", "lydian", "augmented", "prometheus"],
             movements: [2, -2, 3, -3, 1, -1, 0, 4, 5],
             durations: [0.5, 1.0, 1.0, 2.0, 0.5],
             maxNotes: 5, rootBase: 60, rootSpread: 3, resolve: true),
        Mood(scales: ["dimWH", "dimHW", "wholeTone", "augmented"],
             movements: [1, 1, -1, -1, 2, -2, 3, 0, 0],
             durations: [0.125, 0.25, 0.125, 0.25, 0.5],
             maxNotes: 8, rootBase: 54, rootSpread: 2, resolve: false),
    ]

    private func compose(seed: String, config: SoundConfig, sampleRate: Double) -> [JingleEvent] {
        // Web parity: melody seed = instance seed + ':' + play id → djb2 → xorshift.
        let melodyRaw = "\(config.seed):\(seed)"
        let hash = YBRng.djb2(melodyRaw)
        var rng = YBRng(hash)
        let mood = Self.moods[min(max(config.mode, 0), Self.moods.count - 1)]

        // Scale pool pick (mood pool, or all), then rotate to a random mode of it.
        let pool = mood.scales ?? Self.scaleTable.map(\.0)
        let baseScale = Self.scaleByName[pool[rng.range(pool.count)]] ?? [0, 2, 4, 7, 9]
        let modeIdx = rng.range(baseScale.count)
        let root12 = baseScale[modeIdx]
        var scale = (0..<baseScale.count).map { i -> Int in
            var semi = baseScale[(modeIdx + i) % baseScale.count] - root12
            if semi < 0 { semi += 12 }
            return semi
        }
        scale.sort()

        func degToSemitone(_ deg: Int) -> Int {
            let len = scale.count
            let oct = Int(floor(Double(deg) / Double(len)))
            let idx = ((deg % len) + len) % len
            return oct * 12 + scale[idx]
        }

        // Note count comes from the RAW HASH (web: `seed % ...`), not the rng stream.
        let lo = 2, hi = max(mood.maxNotes, 2)
        let numNotes = lo + Int(hash % UInt32(hi - lo + 1))
        let rootMidi = mood.rootBase + rng.range(mood.rootSpread) * 12
        var currentDeg = rng.range(scale.count)

        let beat = 60.0 / min(max(config.bpm, 40), 300)
        var events: [JingleEvent] = []
        var t = 0.0
        for i in 0..<numNotes {
            if mood.resolve, i == numNotes - 1 {
                let targets = [0, 2, scale.count]   // root, 3rd degree, octave — the cadence
                currentDeg = targets[rng.range(targets.count)]
            } else {
                currentDeg += mood.movements[rng.range(mood.movements.count)]
            }
            let raw = rootMidi + degToSemitone(currentDeg)
            let note = Int32(raw < 42 ? raw + 12 : raw > 84 ? raw - 12 : raw)
            let dur = mood.durations[rng.range(mood.durations.count)] * beat

            events.append(JingleEvent(frame: Int(t * sampleRate), on: true, note: note, vel: 112))
            events.append(JingleEvent(frame: Int((t + dur) * sampleRate), on: false, note: note, vel: 0))
            t += dur
        }
        return events   // built in time order; release tails ring past the last off
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
        // Release anything still ringing from the previous jingle: a sounding note is one
        // whose OFF is still pending — send those offs now, since we're about to drop them.
        // (Filtering on pending ONs — notes that never started — left sustains ringing forever.)
        for e in events[min(cursor, events.count)...] where !e.on { fm_note_off(synth, e.note) }
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

/// Web-parity RNG: djb2 string hash + the exact xorshift/rotate step from
/// yamabruh-notify.js `_rng` — same seed, same tune as the web's note brain.
struct YBRng {
    private var s: UInt32

    init(_ seed: UInt32) { s = seed == 0 ? 1 : seed }

    static func djb2(_ str: String) -> UInt32 {
        var h: UInt32 = 5381
        for b in str.utf8 { h = h &* 33 &+ UInt32(b) }
        return h
    }

    mutating func next() -> UInt32 {
        s ^= s << 13
        s = (s >> 17) | (s << 15)   // 32-bit rotate, exactly as the JS does it
        s ^= s << 5
        if s == 0 { s = 1 }
        return s
    }

    mutating func range(_ n: Int) -> Int { n <= 0 ? 0 : Int(next() % UInt32(n)) }
}
