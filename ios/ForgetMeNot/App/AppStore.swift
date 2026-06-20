import SwiftUI
import CoreData   // .NSPersistentStoreRemoteChange (CloudKit import notifications)

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
    @ObservationIgnored private var remoteChangeToken: (any NSObjectProtocol)?

    /// Bump to reseed from the web set. Demo-phase: a higher version wipes existing
    /// tasks and reseeds (revisit once there's real user data — then seed-if-empty only).
    private let seedVersion = 6

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
        observeCloudChanges()
    }

    /// Reload the in-memory snapshot whenever CloudKit imports remote changes, so a reset
    /// or new task made on another device shows up live (the repository is a manual
    /// snapshot, not a live @Query, so it needs this nudge).
    private func observeCloudChanges() {
        remoteChangeToken = NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.load() }
        }
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

    /// Reset a recurring task's cycle (left swipe): start a fresh randomized instance and log
    /// it. Urgency drops to zero and nudges re-arm. Does NOT launch the follow-up chain —
    /// that's a deliberate action now (`launchFollowUps`).
    func reset(id: String) {
        guard let task = tasks.first(where: { $0.id == id }) else { return }
        var rng = SystemRandomNumberGenerator()
        let result = Lifecycle.reset(task, note: "", now: Date(), rng: &rng)
        try? repository.upsert(result.task)
        load()
    }

    /// Launch a task's follow-ups on demand (STEPS swipe) — activate its dormant children.
    func launchFollowUps(id: String) {
        activateChildren(of: id)
        load()
    }

    /// Mark a task done. Removes it from the active list and launches its own follow-ups
    /// (so finishing one chain link surfaces the next).
    func complete(id: String, note: String = "") {
        guard let task = tasks.first(where: { $0.id == id }) else { return }
        let result = Lifecycle.complete(task, note: note, now: Date())
        try? repository.upsert(result.task)
        activateChildren(of: id)
        load()
    }

    /// Bring an inactive (done / paused) or dormant task back into action: open it, clear
    /// completion, and give it a live cycle — recurring → a fresh instance; one-time → a
    /// fresh due date. Used by drag-to-activate in the All Tasks view.
    func reactivate(id: String) {
        guard var t = tasks.first(where: { $0.id == id }) else { return }
        let now = Date()
        t.status = .open
        t.completedAt = nil
        if t.recurring, let base = t.baseCadenceSeconds {
            var rng = SystemRandomNumberGenerator()
            t.instance = ReminderInstanceDTO(
                startedAt: now,
                actualCadenceSeconds: Cadence.randomized(base: base, more: t.cadenceMore, less: t.cadenceLess, using: &rng),
                snoozed: false)
        } else {
            t.startedAt = now
            t.dueDate = now.addingTimeInterval(t.baseCadenceSeconds ?? 3600)
        }
        t.updatedAt = now
        try? repository.upsert(t)
        load()
    }

    /// The right-swipe "done" action: reset a recurring task's cycle (or complete a one-time
    /// link), AND fire its follow-up sub-tasks (activate dormant children). Left-swipe reset,
    /// by contrast, never fires them.
    func markDone(id: String) {
        guard let task = tasks.first(where: { $0.id == id }) else { return }
        if task.recurring {
            var rng = SystemRandomNumberGenerator()
            try? repository.upsert(Lifecycle.reset(task, note: "", action: .done, now: Date(), rng: &rng).task)
        } else {
            try? repository.upsert(Lifecycle.complete(task, note: "", action: .done, now: Date()).task)
        }
        activateChildren(of: id)
        load()
    }

    /// The left-swipe "skip": restart the cycle (recurring) or dismiss the link (one-time)
    /// WITHOUT firing follow-ups; logged as `skipped` in history.
    func skip(id: String) {
        guard let task = tasks.first(where: { $0.id == id }) else { return }
        if task.recurring {
            var rng = SystemRandomNumberGenerator()
            try? repository.upsert(Lifecycle.reset(task, note: "", action: .skipped, now: Date(), rng: &rng).task)
        } else {
            try? repository.upsert(Lifecycle.complete(task, note: "", action: .skipped, now: Date()).task)
        }
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

    /// Add a follow-up: a real, non-repeating CHILD task linked to this one. It starts
    /// "dormant" (no due date → hidden from the main list) until the chain is launched. Tap
    /// it in the detail to configure it or give it its OWN follow-ups (nesting). Returns its id.
    @discardableResult
    func addFollowUp(parentId: String, title: String, cadenceSeconds: Double) -> String? {
        guard let parent = tasks.first(where: { $0.id == parentId }) else { return nil }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let now = Date()
        let child = TaskDTO(
            id: UUID().uuidString, title: trimmed, description: "", domain: parent.domain, tags: [],
            status: .open, priority: .normal, createdAt: now, updatedAt: now,
            dueDate: nil, startedAt: nil, completedAt: nil, estimatedHours: nil,
            recurring: false, baseCadenceSeconds: cadenceSeconds, cadenceMore: nil, cadenceLess: nil,
            instance: nil, followUps: [], parentTaskId: parentId, prompts: [], soundSeed: nil, actionLog: [])
        try? repository.upsert(child)
        load()
        return child.id
    }

    /// This task's follow-ups — child tasks linked via parentTaskId (dormant + active).
    func children(of id: String) -> [TaskDTO] {
        tasks.filter { $0.parentTaskId == id }
    }

    /// A dormant follow-up = non-repeating, has a parent, no due date yet → hidden from the
    /// main list until its chain is launched.
    func isDormantFollowUp(_ t: TaskDTO) -> Bool {
        !t.recurring && t.parentTaskId != nil && t.dueDate == nil
    }

    /// Activate a task's direct dormant children — give each a due date so it surfaces in the
    /// list. Drives both launching a chain (STEPS) and advancing it (on completing a step).
    private func activateChildren(of id: String, now: Date = Date()) {
        for var child in children(of: id) where isDormantFollowUp(child) {
            let offset = child.baseCadenceSeconds ?? 3600
            child.startedAt = now
            child.dueDate = now.addingTimeInterval(offset)
            child.updatedAt = now
            try? repository.upsert(child)
        }
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
            .filter { !isDormantFollowUp($0) }   // hide un-launched follow-up steps
            .sorted { Urgency.ratio($0, now: now) > Urgency.ratio($1, now: now) }
    }

    var sortedActive: [TaskDTO] { activeSorted(now: Date()) }
}
