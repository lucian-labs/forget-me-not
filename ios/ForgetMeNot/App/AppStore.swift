import SwiftUI

/// App-wide observable state. Holds the in-memory list of tasks (web-identical DTOs)
/// and persists through the repository. Seeds a few sample tasks on first launch so
/// a fresh install isn't empty.
@MainActor
@Observable
final class AppStore {
    private let repository: TaskRepository
    var tasks: [TaskDTO] = []

    init(repository: TaskRepository) {
        self.repository = repository
        load()
        if tasks.isEmpty {
            for task in Seed.tasks() { try? repository.upsert(task) }
            load()
        }
    }

    func load() {
        tasks = (try? repository.all()) ?? []
    }

    /// Active tasks, most urgent first.
    var sortedActive: [TaskDTO] {
        tasks
            .filter { $0.status != .done && $0.status != .archived && $0.status != .cancelled }
            .sorted { Urgency.ratio($0) > Urgency.ratio($1) }
    }
}
