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

    /// A FRESH context per call. The container's long-lived `mainContext` caches its own
    /// snapshot and does not merge the changes NSPersistentCloudKitContainer imports into the
    /// store while the app runs — so reads through it go stale (a swipe made on another device
    /// lands in the SQLite store but never shows), and writes through it can miss a
    /// remotely-created row and insert a DUPLICATE (no unique constraint, CloudKit-style). A new
    /// context reads straight from the store every time, so imports are always visible.
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
        let context = freshContext()
        if let existing = entity(task.id, in: context) {
            TaskMapper.apply(task, to: existing)
        } else {
            context.insert(TaskMapper.entity(from: task))
        }
        try context.save()
    }

    func delete(_ id: String) throws {
        let context = freshContext()
        if let e = entity(id, in: context) { context.delete(e); try context.save() }
    }
}
