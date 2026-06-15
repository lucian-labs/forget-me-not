import SwiftUI

/// App-wide observable state. Holds the in-memory list of tasks (web-identical DTOs)
/// and persists through the repository. Seeds a few sample tasks on first launch so
/// a fresh install isn't empty.
@MainActor
@Observable
final class AppStore {
    private let repository: TaskRepository
    var tasks: [TaskDTO] = []

    /// Bump to reseed from the web set. Demo-phase: a higher version wipes existing
    /// tasks and reseeds (revisit once there's real user data — then seed-if-empty only).
    private let seedVersion = 2

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

    func task(_ id: String) -> TaskDTO? { tasks.first { $0.id == id } }

    /// Active tasks, most urgent first.
    var sortedActive: [TaskDTO] {
        tasks
            .filter { $0.status != .done && $0.status != .archived && $0.status != .cancelled }
            .sorted { Urgency.ratio($0) > Urgency.ratio($1) }
    }
}
