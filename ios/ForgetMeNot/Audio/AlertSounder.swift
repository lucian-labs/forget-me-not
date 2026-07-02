import Foundation

/// Web-parity alert sounds (`src/sounds.ts` playAlert/clearAlert): when a task crosses 100%
/// it plays its jingle ONCE, re-arming only after the task drops back under 100% (reset /
/// done / snooze). Each task's seed (its `soundSeed` or id) keeps its jingle recognizable.
@MainActor
@Observable
final class AlertSounder {
    private let synth = SynthEngine()
    private var alerted: Set<String> = []

    /// Reconcile against the current task list — called from the list ticker and on open.
    func evaluate(_ tasks: [TaskDTO], config: SoundConfig, now: Date = Date()) {
        var pending: [TaskDTO] = []
        for task in tasks where task.status == .open {
            guard task.instance != nil || task.dueDate != nil else { continue }
            if Urgency.ratio(task, now: now) >= 1.0 {
                guard config.enabled else { continue }   // muted: stay un-armed so enabling alerts later
                if alerted.insert(task.id).inserted { pending.append(task) }
            } else {
                alerted.remove(task.id)
            }
        }
        guard !pending.isEmpty else { return }
        // Stagger a burst (e.g. opening onto several overdue tasks) instead of a pile-up;
        // cap it — beyond a few, more jingles is noise, and they're all marked alerted anyway.
        for (i, task) in pending.prefix(4).enumerated() {
            let seed = (task.soundSeed?.isEmpty == false) ? task.soundSeed! : task.id
            Task { [synth] in
                try? await Task.sleep(nanoseconds: UInt64(i) * 1_400_000_000)
                synth.play(seed: seed, config: config)
            }
        }
    }

    /// Settings "TEST" button — random seed so repeated taps audition the variety.
    func test(config: SoundConfig) {
        synth.play(seed: "test-\(UInt64.random(in: 0...UInt64.max))", config: config)
    }

    /// Preview one specific task's jingle (same seed the alert will use).
    func preview(_ task: TaskDTO, config: SoundConfig) {
        let seed = (task.soundSeed?.isEmpty == false) ? task.soundSeed! : task.id
        synth.play(seed: seed, config: config)
    }
}
