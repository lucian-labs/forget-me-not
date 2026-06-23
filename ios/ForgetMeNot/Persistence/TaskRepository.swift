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

    /// Owns the container so it can't be deallocated out from under any context it vends.
    init(container: ModelContainer) {
        self.container = container
    }

    /// WRITES go through the mainContext — that's the context NSPersistentCloudKitContainer
    /// watches to EXPORT changes; saving through ad-hoc contexts left the export queue empty.
    private var writeContext: ModelContext { container.mainContext }

    /// READS go through a fresh context. The long-lived mainContext keeps serving the stale
    /// registered copy of a task after CloudKit imports an UPDATE to it (e.g. a reset from
    /// another device) — so creates showed up but resets didn't. A new context reads straight
    /// from the store, so imported updates are always visible.
    private func freshContext() -> ModelContext { ModelContext(container) }

    private func entity(_ id: String, in context: ModelContext) -> TaskEntity? {
        // Fetch-and-filter rather than #Predicate: on the iOS 26 SDK a #Predicate over
        // a @Model with Data-backed (Codable) attributes traps during fetch. Result
        // sets are small and fully local, so the full fetch is cheap.
        (try? context.fetch(FetchDescriptor<TaskEntity>()))?.first { $0.id == id }
    }

    func all() throws -> [TaskDTO] {
        try freshContext().fetch(FetchDescriptor<TaskEntity>()).map(TaskMapper.dto(from:))
    }

    func get(_ id: String) -> TaskDTO? {
        entity(id, in: freshContext()).map(TaskMapper.dto(from:))
    }

    func upsert(_ task: TaskDTO) throws {
        let context = writeContext
        if let existing = entity(task.id, in: context) {
            TaskMapper.apply(task, to: existing)
        } else {
            context.insert(TaskMapper.entity(from: task))
        }
        try context.save()
    }

    func delete(_ id: String) throws {
        let context = writeContext
        if let e = entity(id, in: context) { context.delete(e); try context.save() }
    }
}
