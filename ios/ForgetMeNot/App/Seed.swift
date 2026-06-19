import Foundation

/// The web app's seed set (`src/seed.ts`), translated 1:1 — 11 recurring micro-habits.
/// Some carry a follow-up CHAIN (`followUps`): non-repeating steps that spawn one at a time
/// as the repeating task is reset/completed (web `spawnFollowUp` parity), each link
/// carrying the rest. Mirrors web `createTask`: each recurring task gets a fresh instance
/// started now with `actualCadenceSeconds == base` (the seeds define no cadence variance).
enum Seed {
    private struct Sub {
        let title: String
        let cadence: Double
    }
    private struct SeedTask {
        let title: String
        let domain: String
        let cadence: Double
        let prompts: [String]
        var subs: [Sub] = []
    }

    private static let seeds: [SeedTask] = [
        SeedTask(title: "eyes off the screen", domain: "health", cadence: 900, prompts: []),
        SeedTask(title: "waterize", domain: "health", cadence: 3600, prompts: []),
        SeedTask(title: "move around", domain: "health", cadence: 3200, prompts: ["stretch", "bend over", "walk and breathe"]),
        SeedTask(title: "communicate", domain: "work", cadence: 7200, prompts: ["social post?", "email an update", "blog", "text"],
                 subs: [Sub(title: "reply to one thread", cadence: 7200), Sub(title: "share what you made", cadence: 86400)]),
        SeedTask(title: "put something away", domain: "home", cadence: 5400, prompts: ["has it been there for 5 days?", "have you used it?", "or move something stagnant"]),
        SeedTask(title: "work out", domain: "health", cadence: 14400, prompts: ["heart rate > 120", "50 squats", "back and legs"],
                 subs: [Sub(title: "stretch out", cadence: 14400), Sub(title: "protein + water", cadence: 14400)]),
        SeedTask(title: "dishes", domain: "home", cadence: 14400, prompts: [], subs: [Sub(title: "wipe the counters", cadence: 14400)]),
        SeedTask(title: "brush teeth", domain: "health", cadence: 28800, prompts: []),
        SeedTask(title: "laundry", domain: "home", cadence: 28800, prompts: [],
                 subs: [Sub(title: "move to dryer", cadence: 3600), Sub(title: "fold + put away", cadence: 7200)]),
        SeedTask(title: "take a walk", domain: "health", cadence: 86400, prompts: ["stretch your legs", "down the street and back", "riverwalk!"]),
        SeedTask(title: "bathrooms", domain: "home", cadence: 604800, prompts: []),
    ]

    static func tasks(now: Date = Date()) -> [TaskDTO] {
        seeds.map { s in
            TaskDTO(
                id: UUID().uuidString, title: s.title, description: "", domain: s.domain, tags: [],
                status: .open, priority: .normal, createdAt: now, updatedAt: now,
                dueDate: nil, startedAt: nil, completedAt: nil, estimatedHours: nil,
                recurring: true, baseCadenceSeconds: s.cadence, cadenceMore: nil, cadenceLess: nil,
                instance: ReminderInstanceDTO(startedAt: now, actualCadenceSeconds: s.cadence, snoozed: false),
                followUps: s.subs.map { FollowUpDTO(title: $0.title, cadenceSeconds: $0.cadence, domain: nil) },
                parentTaskId: nil, prompts: s.prompts, soundSeed: nil, actionLog: []
            )
        }
    }
}
