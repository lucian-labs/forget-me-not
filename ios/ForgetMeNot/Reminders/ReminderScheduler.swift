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
        // Notify only when a task reaches its end (100%), then at every subsequent
        // full cadence (200%, 300%, …). In-app nudges handle the finer escalation.
        for task in tasks where task.recurring {
            guard let inst = task.instance, inst.actualCadenceSeconds > 0 else { continue }
            for n in 1...5 {
                let fire = inst.startedAt.addingTimeInterval(inst.actualCadenceSeconds * Double(n))
                let delay = fire.timeIntervalSince(now)
                guard delay > 0 else { continue }

                let content = UNMutableNotificationContent()
                content.title = task.title
                content.body = n == 1
                    ? (task.prompts.randomElement() ?? "\(task.title) is due.")
                    : "\(task.title) — still waiting (\(n)× over)."
                content.sound = .default
                content.userInfo = ["taskId": task.id]

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
                let request = UNNotificationRequest(identifier: "\(task.id)|\(n)", content: content, trigger: trigger)
                try? await center.add(request)
            }
        }
    }
}
