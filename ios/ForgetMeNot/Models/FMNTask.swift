import Foundation

enum TaskStatus: String, Codable, CaseIterable, Identifiable {
    case open
    case inProgress = "in_progress"
    case blocked
    case done
    case cancelled
    case archived

    var id: String { rawValue }

    var label: String {
        switch self {
        case .open: "Open"
        case .inProgress: "In Progress"
        case .blocked: "Blocked"
        case .done: "Done"
        case .cancelled: "Cancelled"
        case .archived: "Archived"
        }
    }
}

enum TaskPriority: String, Codable, CaseIterable, Identifiable {
    case low, normal, high, critical
    var id: String { rawValue }
}

enum ActionType: String, Codable {
    case reset, complete, note
}

struct FollowUp: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var title: String
    var cadenceSeconds: Double
    var domain: String?

    enum CodingKeys: String, CodingKey {
        case title, cadenceSeconds, domain
    }

    init(title: String, cadenceSeconds: Double, domain: String? = nil) {
        self.title = title
        self.cadenceSeconds = cadenceSeconds
        self.domain = domain
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decode(String.self, forKey: .title)
        cadenceSeconds = try c.decode(Double.self, forKey: .cadenceSeconds)
        domain = try c.decodeIfPresent(String.self, forKey: .domain)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(title, forKey: .title)
        try c.encode(cadenceSeconds, forKey: .cadenceSeconds)
        try c.encodeIfPresent(domain, forKey: .domain)
    }
}

struct ActionLogEntry: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var note: String
    var at: Date
    var action: ActionType

    enum CodingKeys: String, CodingKey {
        case note, at, action
    }

    init(note: String, at: Date = Date(), action: ActionType) {
        self.note = note
        self.at = at
        self.action = action
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        note = try c.decode(String.self, forKey: .note)
        at = try c.decode(Date.self, forKey: .at)
        action = try c.decode(ActionType.self, forKey: .action)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(note, forKey: .note)
        try c.encode(at, forKey: .at)
        try c.encode(action, forKey: .action)
    }
}

struct FMNTask: Codable, Identifiable, Equatable {
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
    var cadenceSeconds: Double?
    var cadenceMore: Double?
    var cadenceLess: Double?
    var lastResetAt: Date?
    var followUps: [FollowUp]
    var parentTaskId: String?
    var prompts: [String]
    var actionLog: [ActionLogEntry]

    init(
        title: String,
        description: String = "",
        domain: String = "",
        tags: [String] = [],
        status: TaskStatus = .open,
        priority: TaskPriority = .normal,
        dueDate: Date? = nil,
        startedAt: Date? = nil,
        recurring: Bool = false,
        cadenceSeconds: Double? = nil,
        cadenceMore: Double? = nil,
        cadenceLess: Double? = nil,
        followUps: [FollowUp] = [],
        parentTaskId: String? = nil,
        prompts: [String] = []
    ) {
        let now = Date()
        self.id = UUID().uuidString
        self.title = title
        self.description = description
        self.domain = domain
        self.tags = tags
        self.status = status
        self.priority = priority
        self.createdAt = now
        self.updatedAt = now
        self.dueDate = dueDate
        self.startedAt = startedAt ?? (dueDate != nil ? now : nil)
        self.completedAt = nil
        self.estimatedHours = nil
        self.recurring = recurring
        self.cadenceSeconds = cadenceSeconds
        self.cadenceMore = cadenceMore
        self.cadenceLess = cadenceLess
        self.lastResetAt = recurring ? now : nil
        self.followUps = followUps
        self.parentTaskId = parentTaskId
        self.prompts = prompts
        self.actionLog = []
    }

    var urgencyRatio: Double {
        let now = Date()
        if recurring, let lastReset = lastResetAt, let cadence = cadenceSeconds, cadence > 0 {
            return now.timeIntervalSince(lastReset) / cadence
        }
        if let due = dueDate, let start = startedAt {
            let total = due.timeIntervalSince(start)
            if total <= 0 { return 1 }
            return now.timeIntervalSince(start) / total
        }
        return 0
    }

    var isOverdue: Bool { urgencyRatio >= 1.0 }

    var isActive: Bool {
        status != .done && status != .archived && status != .cancelled
    }
}
