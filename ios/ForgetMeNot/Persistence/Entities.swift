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
    var followUps: [FollowUpDTO] = []
    var parentTaskId: String?
    var prompts: [String] = []
    var soundSeed: String?
    var actionLog: [ActionLogEntryDTO] = []

    init(id: String, title: String) {
        self.id = id
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
