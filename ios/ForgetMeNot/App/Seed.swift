import Foundation

/// The web app's seed set (`src/seed.ts`), translated 1:1 — 11 recurring micro-habits —
/// plus sub-tasks (follow-ups). A sub-task is just another task linked to its parent via
/// `parentTaskId`; it shows in the main list AND under the parent's FOLLOW-UPS section.
/// Mirrors web `createTask`: each recurring task gets a fresh instance started now with
/// `actualCadenceSeconds == base` (the seeds define no cadence variance).
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
        var out: [TaskDTO] = []
        for s in seeds {
            let parentId = UUID().uuidString
            out.append(make(id: parentId, title: s.title, domain: s.domain, cadence: s.cadence,
                            prompts: s.prompts, parent: nil, now: now))
            for sub in s.subs {
                out.append(make(id: UUID().uuidString, title: sub.title, domain: s.domain, cadence: sub.cadence,
                                prompts: [], parent: parentId, now: now))
            }
        }
        return out
    }

    private static func make(id: String, title: String, domain: String, cadence: Double,
                             prompts: [String], parent: String?, now: Date) -> TaskDTO {
        TaskDTO(
            id: id, title: title, description: "", domain: domain, tags: [],
            status: .open, priority: .normal, createdAt: now, updatedAt: now,
            dueDate: nil, startedAt: nil, completedAt: nil, estimatedHours: nil,
            recurring: true, baseCadenceSeconds: cadence, cadenceMore: nil, cadenceLess: nil,
            instance: ReminderInstanceDTO(startedAt: now, actualCadenceSeconds: cadence, snoozed: false),
            followUps: [], parentTaskId: parent, prompts: prompts, soundSeed: nil, actionLog: []
        )
    }
}
