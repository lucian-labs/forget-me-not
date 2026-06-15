import Foundation
import UserNotifications

/// Schedules local notifications at each recurring task's 80% / 90% / 100% marks so the
/// reminder fires even when the app is closed. Local notifications need only runtime
/// authorization — no entitlement, no server. Re-synced on launch and on foreground.
@MainActor
final class ReminderScheduler {
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() async {
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func sync(_ tasks: [TaskDTO], now: Date = Date()) async {
        center.removeAllPendingNotificationRequests()
        let marks: [(frac: Double, phrase: String)] = [
            (0.8, "is getting close"),
            (0.9, "is almost due"),
            (1.0, "is due now"),
        ]
        for task in tasks where task.recurring {
            guard let inst = task.instance, inst.actualCadenceSeconds > 0 else { continue }
            for mark in marks {
                let fire = inst.startedAt.addingTimeInterval(inst.actualCadenceSeconds * mark.frac)
                let delay = fire.timeIntervalSince(now)
                guard delay > 0 else { continue }

                let content = UNMutableNotificationContent()
                content.title = task.title
                content.body = task.prompts.randomElement() ?? "\(task.title) \(mark.phrase)."
                content.sound = .default
                content.userInfo = ["taskId": task.id]

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "\(task.id)|\(mark.frac)",
                    content: content,
                    trigger: trigger
                )
                try? await center.add(request)
            }
        }
    }
}
