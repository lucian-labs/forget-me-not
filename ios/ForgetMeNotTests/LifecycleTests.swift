import XCTest
@testable import ForgetMeNot

final class LifecycleTests: XCTestCase {
    private func recurring(now: Date) -> TaskDTO {
        TaskDTO(id: "x", title: "t", description: "", domain: "home", tags: ["a"], status: .open,
                priority: .normal, createdAt: now, updatedAt: now, dueDate: nil, startedAt: nil,
                completedAt: nil, estimatedHours: nil, recurring: true, baseCadenceSeconds: 100,
                cadenceMore: 0, cadenceLess: 0,
                instance: .init(startedAt: now.addingTimeInterval(-300), actualCadenceSeconds: 100, snoozed: false),
                followUps: [.init(title: "next", cadenceSeconds: 50, domain: nil)],
                parentTaskId: nil, prompts: [], soundSeed: nil, actionLog: [])
    }

    func test_resetStartsNewInstanceAndLogs() {
        let now = Date(timeIntervalSince1970: 2_000_000)
        var rng = SeededRNG(seed: 7)
        let r = Lifecycle.reset(recurring(now: now), note: "did it", now: now, rng: &rng)
        XCTAssertEqual(r.task.instance?.startedAt, now)
        XCTAssertEqual(r.task.actionLog.last?.action, .reset)
        XCTAssertEqual(r.task.actionLog.last?.note, "did it")
        XCTAssertEqual(r.spawned?.title, "next")          // first follow-up spawned
        XCTAssertEqual(r.spawned?.parentTaskId, "x")
    }

    func test_completeMarksDoneAndLogs() {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let r = Lifecycle.complete(recurring(now: now), note: "done", now: now)
        XCTAssertEqual(r.task.status, .done)
        XCTAssertEqual(r.task.completedAt, now)
        XCTAssertEqual(r.task.actionLog.last?.action, .complete)
    }

    func test_snoozeSetsRatioToShortReprieve() {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let s = Lifecycle.snooze(recurring(now: now), now: now)
        // Web parity (store.ts:177): snooze leaves ~75% of the cycle elapsed → a short reprieve.
        XCTAssertEqual(Urgency.ratio(s, now: now), 0.75, accuracy: 0.0001)
        XCTAssertEqual(s.instance?.snoozed, true)
    }

    func test_doubleLapsedDetected() {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let t = recurring(now: now)   // started 300s ago, cadence 100 → ratio 3.0 ≥ 2
        XCTAssertTrue(Lifecycle.isDoubleLapsed(t, now: now))
    }
}
