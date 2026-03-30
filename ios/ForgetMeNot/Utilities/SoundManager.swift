import AVFoundation
import UIKit

final class SoundManager {
    static let shared = SoundManager()

    private let engine = AVAudioEngine()
    private var alertedTasks: Set<String> = []

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    func playTone(frequency: Double = 880, duration: Double = 0.25, volume: Float = 0.4) {
        let output = engine.outputNode
        let sampleRate = output.outputFormat(forBus: 0).sampleRate
        guard sampleRate > 0 else { return }

        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }

        buffer.frameLength = frameCount
        let data = buffer.floatChannelData![0]

        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let attack = min(t / 0.005, 1)
            let release = min((duration - t) / 0.03, 1)
            let envelope = attack * release
            data[i] = Float(sin(2 * .pi * frequency * t) * envelope * Double(volume))
        }

        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)

        do {
            if !engine.isRunning { try engine.start() }
            player.scheduleBuffer(buffer) { [weak self] in
                DispatchQueue.main.async {
                    player.stop()
                    self?.engine.detach(player)
                }
            }
            player.play()
        } catch {}
    }

    func playAlert(for taskId: String, settings: AppSettings) {
        guard settings.soundEnabled, !alertedTasks.contains(taskId) else { return }
        alertedTasks.insert(taskId)

        let baseFreq = 440.0 + Double(settings.soundPreset % 12) * 40.0
        playTone(frequency: baseFreq, volume: Float(settings.soundVolume))

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }

    func clearAlert(for taskId: String) {
        alertedTasks.remove(taskId)
    }

    func playTest(settings: AppSettings) {
        let baseFreq = 440.0 + Double(settings.soundPreset % 12) * 40.0
        playTone(frequency: baseFreq, volume: Float(settings.soundVolume))

        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}
