import AVFoundation
import Foundation

/// Everything the synth needs to voice an alert — mirrors the web app's sound settings
/// (`src/sounds.ts`): the global seed flavors EVERY jingle (web: YamaBruh's constructor
/// seed), preset picks the character, mode picks the scale, plus bpm + volume.
struct SoundConfig: Equatable {
    var enabled: Bool
    var seed: String
    var preset: Int
    var bpm: Double
    var volume: Double
    var mode: Int
}

/// Native stand-in for the web's YamaBruh synth: a tiny seeded chip-tune generator.
/// Each play renders a short jingle into a PCM buffer — the seed (per task) picks the
/// melody deterministically, so every task keeps its own recognizable sound, exactly
/// like the web version. No assets, no network; pure math into AVAudioEngine.
@MainActor
final class SynthEngine {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate: Double = 44_100
    private var started = false

    /// Render + play one jingle. A new play cuts off the previous one.
    func play(seed: String, config: SoundConfig) {
        guard start(), let buffer = render(seed: seed, config: config) else { return }
        player.stop()
        player.scheduleBuffer(buffer, at: nil)
        player.play()
    }

    private func start() -> Bool {
        if started { return true }
        // .playback + mixWithOthers: audible without pausing the user's music.
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return false }
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        do { try engine.start() } catch { return false }
        started = true
        return true
    }

    // MARK: - jingle synthesis

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

    private func render(seed: String, config: SoundConfig) -> AVAudioPCMBuffer? {
        // Full jingle identity = global seed | task seed | preset. Same trio, same tune,
        // forever — and changing the global seed re-rolls the whole soundscape at once.
        var rng = JingleRNG(seed: "\(config.seed)|\(seed)|\(config.preset)")
        let scale = Self.scales[((config.mode % Self.scales.count) + Self.scales.count) % Self.scales.count]

        let bpm = min(max(config.bpm, 50), 260)
        let step = 60.0 / bpm / 2.0                       // eighth notes
        let noteCount = 5 + Int(rng.next() % 4)           // 5–8 notes
        let root = 52 + Int(rng.next() % 17)              // E3..A4 region
        let wave = Int(rng.next() % 4)                    // square / thin pulse / triangle / saw
        let subOn = rng.next() % 3 == 0                   // occasional sine an octave down

        // Random walk on the scale, with an occasional octave hop.
        var degrees: [Int] = []
        var degree = Int(rng.next() % UInt64(scale.count))
        for _ in 0..<noteCount {
            degrees.append(degree)
            let hop = rng.next() % 8
            if hop == 0 { degree += scale.count }         // up an octave
            else if hop == 1 { degree -= scale.count }
            else { degree += Int(rng.next() % 5) - 2 }    // -2...+2 steps
            degree = min(max(degree, -scale.count), scale.count * 2)
        }

        let tail = step * 2.5                             // let the last note ring
        let total = step * Double(noteCount) + tail
        let frames = AVAudioFrameCount(total * sampleRate)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let out = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames
        for i in 0..<Int(frames) { out[i] = 0 }

        let amp = Float(min(max(config.volume, 0), 1)) * 0.5
        for (n, deg) in degrees.enumerated() {
            let octave = Int(floor(Double(deg) / Double(scale.count)))
            let idx = ((deg % scale.count) + scale.count) % scale.count
            let midi = root + octave * 12 + scale[idx]
            let freq = 440.0 * pow(2.0, (Double(midi) - 69.0) / 12.0)
            let isLast = n == noteCount - 1
            let dur = isLast ? step + tail : step
            let startFrame = Int(Double(n) * step * sampleRate)
            let noteFrames = Int(dur * sampleRate)
            let decay = (isLast ? 0.5 : 0.22) * dur       // exponential envelope tau

            var phase = 0.0, subPhase = 0.0
            for f in 0..<noteFrames {
                let i = startFrame + f
                if i >= Int(frames) { break }
                let t = Double(f) / sampleRate
                let env = Float(min(t / 0.003, 1) * exp(-t / decay))
                var s: Float
                switch wave {
                case 0: s = phase < 0.5 ? 1 : -1
                case 1: s = phase < 0.25 ? 1 : -1
                case 2: s = Float(4 * abs(phase - 0.5) - 1)
                default: s = Float(2 * phase - 1)
                }
                if subOn { s += Float(sin(subPhase * 2 * .pi)) * 0.35 }
                out[i] += max(-1, min(1, s * env * amp))
                phase += freq / sampleRate; if phase >= 1 { phase -= 1 }
                subPhase += (freq / 2) / sampleRate; if subPhase >= 1 { subPhase -= 1 }
            }
        }
        return buffer
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
