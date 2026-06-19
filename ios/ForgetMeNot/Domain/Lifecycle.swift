import Foundation

enum Lifecycle {
    struct ResetResult { var task: TaskDTO; var spawned: TaskDTO? }

    static func reset<R: RandomNumberGenerator>(_ t: TaskDTO, note: String, now: Date = Date(), rng: inout R) -> ResetResult {
        // Web parity (store.ts:138): reset is a no-op without a base cadence.
        guard let base = t.baseCadenceSeconds else { return ResetResult(task: t, spawned: nil) }
        var task = t
        let cadence = Cadence.randomized(base: base, more: t.cadenceMore, less: t.cadenceLess, using: &rng)
        task.instance = ReminderInstanceDTO(startedAt: now, actualCadenceSeconds: cadence, snoozed: false)
        task.actionLog.append(ActionLogEntryDTO(note: note, at: now, action: .reset))
        task.updatedAt = now
        // Reset is purely a timer restart — it does NOT launch the follow-up chain. (The web
        // spawned here; we intentionally diverge. Use launchFollowUps to start a chain.)
        return ResetResult(task: task, spawned: nil)
    }

    struct CompleteResult { var task: TaskDTO; var spawned: TaskDTO? }

    static func complete(_ t: TaskDTO, note: String, now: Date = Date()) -> CompleteResult {
        var task = t
        task.status = .done
        task.completedAt = now
        task.actionLog.append(ActionLogEntryDTO(note: note, at: now, action: .complete))
        task.updatedAt = now
        return CompleteResult(task: task, spawned: spawnFollowUp(from: task, now: now))
    }

    static func snooze(_ t: TaskDTO, now: Date = Date()) -> TaskDTO {
        guard var inst = t.instance else { return t }
        // Web parity (store.ts:177): startedAt = now - 0.75*cadence, so ~75% of the
        // cycle has elapsed (ratio 0.75) → a short reprieve before it re-alerts.
        inst.startedAt = now.addingTimeInterval(-0.75 * inst.actualCadenceSeconds)
        inst.snoozed = true
        var task = t
        task.instance = inst
        task.updatedAt = now
        return task
    }

    static func note(_ t: TaskDTO, note: String, now: Date = Date()) -> TaskDTO {
        var task = t
        task.actionLog.append(ActionLogEntryDTO(note: note, at: now, action: .note))
        task.updatedAt = now
        return task
    }

    static func isDoubleLapsed(_ t: TaskDTO, now: Date = Date()) -> Bool {
        t.recurring && t.instance != nil && Urgency.ratio(t, now: now) >= 2.0
    }

    static func spawnFollowUp(from parent: TaskDTO, now: Date = Date()) -> TaskDTO? {
        guard let first = parent.followUps.first else { return nil }
        let remaining = Array(parent.followUps.dropFirst())
        let due = now.addingTimeInterval(first.cadenceSeconds)
        return TaskDTO(
            id: UUID().uuidString, title: first.title, description: first.details ?? "",
            domain: first.domain ?? parent.domain, tags: parent.tags, status: .open,
            priority: .normal, createdAt: now, updatedAt: now, dueDate: due, startedAt: now,
            completedAt: nil, estimatedHours: nil, recurring: false, baseCadenceSeconds: nil,
            cadenceMore: nil, cadenceLess: nil, instance: nil, followUps: remaining,
            // Web parity (store.ts:228-241): a spawned follow-up does NOT inherit
            // prompts or soundSeed — only title/domain/tags/followUps/parent.
            parentTaskId: parent.id, prompts: [], soundSeed: nil, actionLog: []
        )
    }
}
