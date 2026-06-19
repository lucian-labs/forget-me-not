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
    private let seedVersion = 4

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

    /// Deliberately kick off this task's follow-up chain — spawns the first step (carrying
    /// the rest). No-op if the task has no chain or a step is already in progress.
    func launchFollowUps(id: String) {
        guard let task = tasks.first(where: { $0.id == id }), !task.followUps.isEmpty else { return }
        if children(of: id).contains(where: { $0.status != .done && $0.status != .archived }) { return }
        if let spawned = Lifecycle.spawnFollowUp(from: task) {
            try? repository.upsert(spawned)
            load()
        }
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

    /// Append a step to a task's follow-up CHAIN. The chain is a list of non-repeating steps;
    /// on each reset/complete the first spawns as a one-time task (carrying the rest), and
    /// finishing that spawns the next — so the chain unfolds one link at a time.
    func addFollowUp(id: String, title: String, cadenceSeconds: Double) {
        guard var t = tasks.first(where: { $0.id == id }) else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        t.followUps.append(FollowUpDTO(title: trimmed, cadenceSeconds: cadenceSeconds, domain: nil))
        t.updatedAt = Date()
        try? repository.upsert(t)
        load()
    }

    func removeFollowUp(id: String, at index: Int) {
        guard var t = tasks.first(where: { $0.id == id }), t.followUps.indices.contains(index) else { return }
        t.followUps.remove(at: index)
        t.updatedAt = Date()
        try? repository.upsert(t)
        load()
    }

    /// Configure a chain step (title / cadence / details). Details flow into the step's
    /// description when it spawns, which drives its icon.
    func updateFollowUp(id: String, at index: Int, title: String, cadenceSeconds: Double, details: String) {
        guard var t = tasks.first(where: { $0.id == id }), t.followUps.indices.contains(index) else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let d = details.trimmingCharacters(in: .whitespacesAndNewlines)
        t.followUps[index] = FollowUpDTO(title: trimmed, cadenceSeconds: cadenceSeconds,
                                         domain: t.followUps[index].domain, details: d.isEmpty ? nil : d)
        t.updatedAt = Date()
        try? repository.upsert(t)
        load()
    }

    /// Steps already spawned from this task's chain (real one-time tasks pointed at it).
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
