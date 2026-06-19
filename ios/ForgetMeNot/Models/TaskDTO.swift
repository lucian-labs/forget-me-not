import Foundation

enum TaskStatus: String, Codable, CaseIterable, Sendable {
    case open, inProgress = "in_progress", blocked, done, cancelled, archived
}
enum TaskPriority: String, Codable, CaseIterable, Sendable {
    case low, normal, high, critical
}
enum ActionType: String, Codable, Sendable {
    case reset, complete, note, lapsed
}

struct FollowUpDTO: Codable, Equatable, Sendable {
    var title: String
    var cadenceSeconds: Double
    var domain: String?
    var details: String? = nil   // flows into the spawned step's description (drives its icon)
}

struct ActionLogEntryDTO: Codable, Equatable, Sendable {
    var note: String
    var at: Date
    var action: ActionType
}

struct ReminderInstanceDTO: Codable, Equatable, Sendable {
    var startedAt: Date
    var actualCadenceSeconds: Double
    var snoozed: Bool
}

struct TaskDTO: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var title: String
    var description: String
    var domain: String
    var tags: [String]
    var status: TaskStatus
    var priority: TaskPriority
    var createdAt: Date
    var updatedAt: Date
    var dueDate: Date?
    var startedAt: Date?
    var completedAt: Date?
    var estimatedHours: Double?
    var recurring: Bool
    var baseCadenceSeconds: Double?
    var cadenceMore: Double?
    var cadenceLess: Double?
    var instance: ReminderInstanceDTO?
    var followUps: [FollowUpDTO]
    var parentTaskId: String?
    var prompts: [String]
    var soundSeed: String?
    var actionLog: [ActionLogEntryDTO]

    enum CodingKeys: String, CodingKey {
        case id, title, description, domain, tags, status, priority, createdAt, updatedAt,
             dueDate, startedAt, completedAt, estimatedHours, recurring, baseCadenceSeconds,
             cadenceMore, cadenceLess, instance, followUps, parentTaskId, prompts, soundSeed, actionLog
    }

    // Custom encode so nullable fields are emitted as explicit `null` (web parity),
    // using `encode` (not `encodeIfPresent`) on optionals.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(description, forKey: .description)
        try c.encode(domain, forKey: .domain)
        try c.encode(tags, forKey: .tags)
        try c.encode(status, forKey: .status)
        try c.encode(priority, forKey: .priority)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encode(dueDate, forKey: .dueDate)
        try c.encode(startedAt, forKey: .startedAt)
        try c.encode(completedAt, forKey: .completedAt)
        try c.encode(estimatedHours, forKey: .estimatedHours)
        try c.encode(recurring, forKey: .recurring)
        try c.encode(baseCadenceSeconds, forKey: .baseCadenceSeconds)
        try c.encode(cadenceMore, forKey: .cadenceMore)
        try c.encode(cadenceLess, forKey: .cadenceLess)
        try c.encode(instance, forKey: .instance)
        try c.encode(followUps, forKey: .followUps)
        try c.encode(parentTaskId, forKey: .parentTaskId)
        try c.encode(prompts, forKey: .prompts)
        try c.encode(soundSeed, forKey: .soundSeed)
        try c.encode(actionLog, forKey: .actionLog)
    }
}
