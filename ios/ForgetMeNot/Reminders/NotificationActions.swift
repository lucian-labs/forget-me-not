import Foundation
import UserNotifications

/// Applies a notification action to a task directly against the persistent store (the action
/// can fire while the app is backgrounded). The app picks the change up on next foreground
/// (AppStore.load on scene-active) and reschedules. Action ids match ReminderScheduler.
enum NotificationActions {
    static let skip = "FMN_SKIP"
    static let done = "FMN_DONE"
    static let snooze = "FMN_SNOOZE"

    @MainActor static func handle(_ action: String, taskId: String) {
        let repo = SwiftDataTaskRepository(container: FMNModelContainer.resolve())
        guard let task = repo.get(taskId) else { return }
        switch action {
        case skip:
            if task.recurring {
                var rng = SystemRandomNumberGenerator()
                try? repo.upsert(Lifecycle.reset(task, note: "", action: .skipped, now: Date(), rng: &rng).task)
            } else {
                try? repo.upsert(Lifecycle.complete(task, note: "", action: .skipped, now: Date()).task)
            }
        case done:
            if task.recurring {
                var rng = SystemRandomNumberGenerator()
                try? repo.upsert(Lifecycle.reset(task, note: "", action: .done, now: Date(), rng: &rng).task)
            } else {
                try? repo.upsert(Lifecycle.complete(task, note: "", action: .done, now: Date()).task)
            }
            activateChildren(of: taskId, repo: repo)
        case snooze:
            try? repo.upsert(Lifecycle.snooze(task, now: Date()))
        default:
            return   // default tap / dismiss — nothing to do
        }
        // Clear the now-stale escalation reminders for this task (1×…5×).
        let ids = (1...5).map { "\(taskId)|\($0)" }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    /// Mirror of AppStore.activateChildren for the headless path: launch dormant follow-ups.
    @MainActor private static func activateChildren(of id: String, repo: TaskRepository) {
        let now = Date()
        for var child in ((try? repo.all()) ?? [])
        where child.parentTaskId == id && !child.recurring && child.dueDate == nil && child.status == .open {
            child.startedAt = now
            child.dueDate = now.addingTimeInterval(child.baseCadenceSeconds ?? 3600)
            child.updatedAt = now
            try? repo.upsert(child)
        }
    }
}
