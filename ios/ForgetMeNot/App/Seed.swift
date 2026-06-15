import Foundation

/// Sample tasks for a fresh install — recurring tasks with live instances at a
/// spread of urgencies so the list shows green/orange/red bars immediately.
enum Seed {
    static func tasks(now: Date = Date()) -> [TaskDTO] {
        [
            recurring("Flip the laundry", domain: "home", base: 2700, startedAgo: 2450,
                      prompts: ["Did you check the pockets?"], now: now),
            recurring("Water the plants", domain: "home", base: 172_800, startedAgo: 86_400,
                      prompts: ["The fern is looking thirsty."], now: now),
            recurring("Stand up & stretch", domain: "body", base: 3600, startedAgo: 700,
                      prompts: ["Roll the shoulders back."], now: now),
        ]
    }

    private static func recurring(
        _ title: String, domain: String, base: Double, startedAgo: Double,
        prompts: [String], now: Date
    ) -> TaskDTO {
        TaskDTO(
            id: UUID().uuidString, title: title, description: "", domain: domain, tags: [],
            status: .open, priority: .normal, createdAt: now, updatedAt: now,
            dueDate: nil, startedAt: nil, completedAt: nil, estimatedHours: nil,
            recurring: true, baseCadenceSeconds: base, cadenceMore: nil, cadenceLess: nil,
            instance: ReminderInstanceDTO(startedAt: now.addingTimeInterval(-startedAgo),
                                          actualCadenceSeconds: base, snoozed: false),
            followUps: [], parentTaskId: nil, prompts: prompts, soundSeed: nil, actionLog: []
        )
    }
}
