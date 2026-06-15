import Foundation
import UserNotifications

/// Schedules local notifications at each recurring task's 100% / 200% / … marks. The
/// "due" (100%) notification carries a freshly generated on-device nudge (cached per
/// cycle so we don't regenerate every foreground), and the task's mascot is attached
/// as the notification image. Local notifications need only runtime authorization.
@MainActor
final class ReminderScheduler {
    private let center = UNUserNotificationCenter.current()
    private let nudges = Nudges.service()
    private var dynamicCache: [String: String] = [:]   // "taskId|instanceStart" -> AI nudge

    func requestAuthorization() async {
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func sync(_ tasks: [TaskDTO], characterURL: (String) -> URL?, now: Date = Date()) async {
        center.removeAllPendingNotificationRequests()
        for task in tasks where task.recurring {
            guard let inst = task.instance, inst.actualCadenceSeconds > 0 else { continue }
            let dueBody = await dynamicBody(for: task, inst: inst)
            let mascot = characterURL(task.id)

            for n in 1...5 {
                let fire = inst.startedAt.addingTimeInterval(inst.actualCadenceSeconds * Double(n))
                let delay = fire.timeIntervalSince(now)
                guard delay > 0 else { continue }

                let content = UNMutableNotificationContent()
                content.title = task.title
                content.body = n == 1 ? dueBody : "\(task.title) — still waiting (\(n)× over)."
                content.sound = .default
                content.userInfo = ["taskId": task.id]
                if let mascot, let att = attachment(mascot, key: "\(task.id)-\(n)") {
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

    /// Stage a temp copy of the mascot PNG (UNNotificationAttachment consumes the file).
    private func attachment(_ src: URL, key: String) -> UNNotificationAttachment? {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("notif-\(key).png")
        try? FileManager.default.removeItem(at: tmp)
        guard (try? FileManager.default.copyItem(at: src, to: tmp)) != nil else { return nil }
        return try? UNNotificationAttachment(identifier: "char-\(key)", url: tmp, options: nil)
    }
}
