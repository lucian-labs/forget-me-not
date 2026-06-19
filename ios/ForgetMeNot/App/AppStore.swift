import SwiftUI

/// App-wide observable state. Holds the in-memory list of tasks (web-identical DTOs)
/// and persists through the repository. Seeds a few sample tasks on first launch so
/// a fresh install isn't empty.
@MainActor
@Observable
final class AppStore {
    private let repository: TaskRepository
    var tasks: [TaskDTO] = []
    var themeName: String = "waveloop"
    var iconStyle: String = ""
    var nudgeStyle: String = ""

    /// Bump to reseed from the web set. Demo-phase: a higher version wipes existing
    /// tasks and reseeds (revisit once there's real user data — then seed-if-empty only).
    private let seedVersion = 3

    init(repository: TaskRepository) {
        self.repository = repository
        load()
        let stored = UserDefaults.standard.integer(forKey: "fmn.seedVersion")
        if tasks.isEmpty || stored < seedVersion {
            for task in tasks { try? repository.delete(task.id) }
            for task in Seed.tasks() { try? repository.upsert(task) }
            UserDefaults.standard.set(seedVersion, forKey: "fmn.seedVersion")
            load()
        }
        themeName = UserDefaults.standard.string(forKey: "fmn.theme") ?? "waveloop"
        WL.apply(Theme.named(themeName))
        iconStyle = UserDefaults.standard.string(forKey: "fmn.iconStyle") ?? ""
        nudgeStyle = UserDefaults.standard.string(forKey: "fmn.nudgeStyle") ?? ""
    }

    func setTheme(_ name: String) {
        themeName = name
        UserDefaults.standard.set(name, forKey: "fmn.theme")
        WL.apply(Theme.named(name))
    }

    func setIconStyle(_ style: String) {
        iconStyle = style
        UserDefaults.standard.set(style, forKey: "fmn.iconStyle")
    }

    func setNudgeStyle(_ style: String) {
        nudgeStyle = style
        UserDefaults.standard.set(style, forKey: "fmn.nudgeStyle")
    }

    func load() {
        tasks = (try? repository.all()) ?? []
    }

    /// Reset a recurring task's cycle (swipe-right): start a fresh randomized instance,
    /// log it, and spawn any follow-up. Urgency drops to zero and nudges re-arm.
    func reset(id: String) {
        guard let task = tasks.first(where: { $0.id == id }) else { return }
        var rng = SystemRandomNumberGenerator()
        let result = Lifecycle.reset(task, note: "", now: Date(), rng: &rng)
        try? repository.upsert(result.task)
        if let spawned = result.spawned { try? repository.upsert(spawned) }
        load()
    }

    /// Mark a task done (and spawn any follow-up). Removes it from the active list.
    func complete(id: String, note: String = "") {
        guard let task = tasks.first(where: { $0.id == id }) else { return }
        let result = Lifecycle.complete(task, note: note, now: Date())
        try? repository.upsert(result.task)
        if let spawned = result.spawned { try? repository.upsert(spawned) }
        load()
    }

    /// Append a note to the action log without changing the cycle.
    func addNote(id: String, note: String) {
        guard let task = tasks.first(where: { $0.id == id }) else { return }
        try? repository.upsert(Lifecycle.note(task, note: note, now: Date()))
        load()
    }

    func delete(id: String) {
        try? repository.delete(id)
        load()
    }

    func create(_ task: TaskDTO) {
        try? repository.upsert(task)
        load()
    }

    /// Link a follow-up — a follow-up is just another task. Finds an existing task by title
    /// (case-insensitive) or creates a new recurring one, then points it at `parentId`.
    /// Returns the linked task's id.
    @discardableResult
    func linkFollowUp(parentId: String, title: String, cadenceSeconds: Double) -> String? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let parent = tasks.first(where: { $0.id == parentId }) else { return nil }
        let now = Date()
        if var existing = tasks.first(where: { $0.id != parentId && $0.title.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            existing.parentTaskId = parentId
            existing.updatedAt = now
            try? repository.upsert(existing)
            load()
            return existing.id
        }
        let new = TaskDTO(
            id: UUID().uuidString, title: trimmed, description: "", domain: parent.domain,
            tags: parent.tags, status: .open, priority: .normal, createdAt: now, updatedAt: now,
            dueDate: nil, startedAt: now, completedAt: nil, estimatedHours: nil, recurring: true,
            baseCadenceSeconds: cadenceSeconds, cadenceMore: nil, cadenceLess: nil,
            instance: ReminderInstanceDTO(startedAt: now, actualCadenceSeconds: cadenceSeconds, snoozed: false),
            followUps: [], parentTaskId: parentId, prompts: [], soundSeed: nil, actionLog: [])
        try? repository.upsert(new)
        load()
        return new.id
    }

    /// Unlink a follow-up: clears the child's parent. Does NOT delete it — it's just
    /// another task and still lives in the main list.
    func unlinkFollowUp(id childId: String) {
        guard var child = tasks.first(where: { $0.id == childId }) else { return }
        child.parentTaskId = nil
        child.updatedAt = Date()
        try? repository.upsert(child)
        load()
    }

    /// This task's follow-ups — tasks pointed at it via parentTaskId.
    func children(of id: String) -> [TaskDTO] {
        tasks.filter { $0.parentTaskId == id }
    }

    func addReminder(id: String, _ text: String) {
        guard var t = tasks.first(where: { $0.id == id }) else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        t.prompts.append(trimmed)
        t.updatedAt = Date()
        try? repository.upsert(t)
        load()
    }

    func removeReminder(id: String, at index: Int) {
        guard var t = tasks.first(where: { $0.id == id }), t.prompts.indices.contains(index) else { return }
        t.prompts.remove(at: index)
        t.updatedAt = Date()
        try? repository.upsert(t)
        load()
    }

    func setDescription(id: String, _ text: String) {
        guard var task = tasks.first(where: { $0.id == id }) else { return }
        task.description = text
        task.updatedAt = Date()
        try? repository.upsert(task)
        load()
    }

    /// Active = open + running. Inactive = paused (asleep): status blocked, instance killed
    /// so urgency freezes and it stops nudging/notifying. Reactivating starts a fresh cycle.
    func setActive(id: String, _ active: Bool) {
        guard var t = tasks.first(where: { $0.id == id }) else { return }
        if active {
            t.status = .open
            if t.recurring, let base = t.baseCadenceSeconds, t.instance == nil {
                var rng = SystemRandomNumberGenerator()
                t.instance = ReminderInstanceDTO(
                    startedAt: Date(),
                    actualCadenceSeconds: Cadence.randomized(base: base, more: t.cadenceMore, less: t.cadenceLess, using: &rng),
                    snoozed: false)
            }
        } else {
            t.status = .blocked
            t.instance = nil
        }
        t.updatedAt = Date()
        try? repository.upsert(t)
        load()
    }

    func isActive(id: String) -> Bool { tasks.first { $0.id == id }?.status == .open }

    func task(_ id: String) -> TaskDTO? { tasks.first { $0.id == id } }

    /// Active tasks, most urgent first at `now`. Urgency rises with time, so the order
    /// changes as the clock advances — the list passes a ticking `now` to re-sort live.
    func activeSorted(now: Date) -> [TaskDTO] {
        tasks
            .filter { $0.status != .done && $0.status != .archived && $0.status != .cancelled }
            .sorted { Urgency.ratio($0, now: now) > Urgency.ratio($1, now: now) }
    }

    var sortedActive: [TaskDTO] { activeSorted(now: Date()) }
}
