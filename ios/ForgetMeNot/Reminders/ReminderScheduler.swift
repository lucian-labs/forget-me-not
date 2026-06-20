import Foundation
import UserNotifications

/// Schedules local notifications at each recurring task's 100% / 200% / … marks. The
/// "due" (100%) notification carries a freshly generated on-device nudge (cached per
/// cycle so we don't regenerate every foreground), and the task's icon is attached
/// as the notification image. Local notifications need only runtime authorization.
@MainActor
final class ReminderScheduler {
    private let center = UNUserNotificationCenter.current()
    private let nudges = Nudges.service()
    private var dynamicCache: [String: String] = [:]   // "taskId|instanceStart" -> AI nudge

    func requestAuthorization() async {
        center.setNotificationCategories([Self.taskCategory])
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// Swipe / long-press a reminder to manage the task without opening the app.
    static let taskCategory: UNNotificationCategory = {
        let done = UNNotificationAction(identifier: NotificationActions.done, title: "Done", options: [])
        let reset = UNNotificationAction(identifier: NotificationActions.reset, title: "Reset Timer", options: [])
        let snooze = UNNotificationAction(identifier: NotificationActions.snooze, title: "Snooze", options: [])
        return UNNotificationCategory(identifier: "FMN_TASK", actions: [done, reset, snooze],
                                      intentIdentifiers: [], options: [])
    }()

    /// Current notification permission (for the Settings status line).
    static func authStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Fire a test reminder in 4 seconds — confirms permission + delivery without waiting for
    /// a real cadence mark. Carries `taskId` so its Done/Reset/Snooze actions work too.
    static func sendTest(taskId: String?) async {
        let center = UNUserNotificationCenter.current()
        center.setNotificationCategories([taskCategory])
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        let content = UNMutableNotificationContent()
        content.title = "Forget Me Not"
        content.body = "Test reminder — long-press for Done / Reset / Snooze."
        content.sound = .default
        content.categoryIdentifier = "FMN_TASK"
        if let taskId { content.userInfo = ["taskId": taskId] }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 4, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: "fmn-test", content: content, trigger: trigger))
    }

    func sync(_ tasks: [TaskDTO], characterURL: (String) -> URL?, now: Date = Date()) async {
        center.removeAllPendingNotificationRequests()
        for task in tasks where task.recurring {
            guard let inst = task.instance, inst.actualCadenceSeconds > 0 else { continue }
            let dueBody = await dynamicBody(for: task, inst: inst)
            let icon = characterURL(task.id)

            for n in 1...5 {
                let fire = inst.startedAt.addingTimeInterval(inst.actualCadenceSeconds * Double(n))
                let delay = fire.timeIntervalSince(now)
                guard delay > 0 else { continue }

                let content = UNMutableNotificationContent()
                content.title = task.title
                content.body = n == 1 ? dueBody : "\(task.title) — still waiting (\(n)× over)."
                content.sound = .default
                content.userInfo = ["taskId": task.id]
                content.categoryIdentifier = "FMN_TASK"
                if let icon, let att = attachment(icon, key: "\(task.id)-\(n)") {
                    content.attachments = [att]
                }

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
                let request = UNNotificationRequest(identifier: "\(task.id)|\(n)", content: content, trigger: trigger)
                try? await center.add(request)
            }
        }
    }

    /// One on-device nudge per cycle (intensity 1 = "it's due"), cached by instance so
    /// foregrounding doesn't regenerate; a reset (new instance) makes a fresh one.
    private func dynamicBody(for task: TaskDTO, inst: ReminderInstanceDTO) async -> String {
        let key = "\(task.id)|\(inst.startedAt.timeIntervalSince1970)"
        if let cached = dynamicCache[key] { return cached }
        let text = await nudges.nudge(for: task, intensity: 1)
        dynamicCache[key] = text
        return text
    }

    /// Stage a temp copy of the icon PNG (UNNotificationAttachment consumes the file).
    private func attachment(_ src: URL, key: String) -> UNNotificationAttachment? {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("notif-\(key).png")
        try? FileManager.default.removeItem(at: tmp)
        guard (try? FileManager.default.copyItem(at: src, to: tmp)) != nil else { return nil }
        return try? UNNotificationAttachment(identifier: "char-\(key)", url: tmp, options: nil)
    }
}
