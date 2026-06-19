import Foundation

/// The web app's seed set (`src/seed.ts`), translated 1:1 — 11 recurring micro-habits.
/// Some carry follow-ups: real, non-repeating CHILD tasks (parentTaskId) that start dormant
/// (no due date → hidden from the list) until the chain is launched. Mirrors web `createTask`:
/// each recurring task gets a fresh instance started now (`actualCadenceSeconds == base`).
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
            out.append(TaskDTO(
                id: parentId, title: s.title, description: "", domain: s.domain, tags: [],
                status: .open, priority: .normal, createdAt: now, updatedAt: now,
                dueDate: nil, startedAt: nil, completedAt: nil, estimatedHours: nil,
                recurring: true, baseCadenceSeconds: s.cadence, cadenceMore: nil, cadenceLess: nil,
                instance: ReminderInstanceDTO(startedAt: now, actualCadenceSeconds: s.cadence, snoozed: false),
                followUps: [], parentTaskId: nil, prompts: s.prompts, soundSeed: nil, actionLog: []))
            // Nest the steps into a sequential chain: head → sub1 → sub2 — each dormant
            // (no due date → hidden) until the previous one launches/completes it.
            var prevId = parentId
            for sub in s.subs {
                let childId = UUID().uuidString
                out.append(TaskDTO(
                    id: childId, title: sub.title, description: "", domain: s.domain, tags: [],
                    status: .open, priority: .normal, createdAt: now, updatedAt: now,
                    dueDate: nil, startedAt: nil, completedAt: nil, estimatedHours: nil,
                    recurring: false, baseCadenceSeconds: sub.cadence, cadenceMore: nil, cadenceLess: nil,
                    instance: nil, followUps: [], parentTaskId: prevId, prompts: [], soundSeed: nil, actionLog: []))
                prevId = childId
            }
        }
        return out
    }
}
