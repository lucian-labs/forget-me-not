import Foundation
import SwiftData

@MainActor
protocol TaskRepository {
    func all() throws -> [TaskDTO]
    func get(_ id: String) -> TaskDTO?
    func upsert(_ task: TaskDTO) throws
    func delete(_ id: String) throws
}

@MainActor
final class SwiftDataTaskRepository: TaskRepository {
    private let container: ModelContainer
    /// All work goes through the container's mainContext. CloudKit mirroring exports the changes
    /// it sees on THIS context — saving through ad-hoc `ModelContext(container)` instances left
    /// the export queue empty (every sync affected 0 objects). The mainContext also auto-merges
    /// CloudKit imports, so reads here reflect another device's changes once they arrive.
    private var context: ModelContext { container.mainContext }

    /// Owns the container so it can't be deallocated out from under the context.
    init(container: ModelContainer) {
        self.container = container
    }

    private func entity(_ id: String) -> TaskEntity? {
        // Fetch-and-filter rather than #Predicate: on the iOS 26 SDK a #Predicate over
        // a @Model with Data-backed (Codable) attributes traps during fetch. Result
        // sets are small and fully local, so the full fetch is cheap.
        (try? context.fetch(FetchDescriptor<TaskEntity>()))?.first { $0.id == id }
    }

    func all() throws -> [TaskDTO] {
        try context.fetch(FetchDescriptor<TaskEntity>()).map(TaskMapper.dto(from:))
    }

    func get(_ id: String) -> TaskDTO? {
        entity(id).map(TaskMapper.dto(from:))
    }

    func upsert(_ task: TaskDTO) throws {
        if let existing = entity(task.id) {
            TaskMapper.apply(task, to: existing)
        } else {
            context.insert(TaskMapper.entity(from: task))
        }
        try context.save()
    }

    func delete(_ id: String) throws {
        if let e = entity(id) { context.delete(e); try context.save() }
    }
}
