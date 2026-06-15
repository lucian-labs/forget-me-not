import Foundation
import SwiftData

@Model
final class TaskEntity {
    var id: String = ""
    var title: String = ""
    var taskDescription: String = ""      // `description` is reserved on NSObject-ish contexts; map in mapper
    var domain: String = ""
    var tags: [String] = []
    var statusRaw: String = TaskStatus.open.rawValue
    var priorityRaw: String = TaskPriority.normal.rawValue
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast
    var dueDate: Date?
    var startedAt: Date?
    var completedAt: Date?
    var estimatedHours: Double?
    var recurring: Bool = false
    var baseCadenceSeconds: Double?
    var cadenceMore: Double?
    var cadenceLess: Double?
    // Embedded ReminderInstance (present iff recurring & live):
    var instanceStartedAt: Date?
    var instanceActualCadenceSeconds: Double?
    var instanceSnoozed: Bool = false
    // Stored as JSON Data to avoid SwiftData's Codable-struct transformer on iOS 26+.
    var followUpsData: Data = Data()
    var actionLogData: Data = Data()
    var parentTaskId: String?
    var prompts: [String] = []
    var soundSeed: String?

    // Computed accessors used by TaskMapper — encode/decode on the fly.
    // @Transient excludes them from the SwiftData schema (they're backed by *Data above).
    @Transient
    var followUps: [FollowUpDTO] {
        get { (try? JSONDecoder().decode([FollowUpDTO].self, from: followUpsData)) ?? [] }
        set { followUpsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    @Transient
    var actionLog: [ActionLogEntryDTO] {
        get { (try? JSONDecoder().decode([ActionLogEntryDTO].self, from: actionLogData)) ?? [] }
        set { actionLogData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    init(id: String, title: String) {
        self.id = id
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
