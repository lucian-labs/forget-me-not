import XCTest
@testable import ForgetMeNot

final class UrgencyTests: XCTestCase {
    private func task(instanceStart: Date, cadence: Double) -> TaskDTO {
        TaskDTO(id: "x", title: "t", description: "", domain: "", tags: [], status: .open,
                priority: .normal, createdAt: .distantPast, updatedAt: .distantPast,
                dueDate: nil, startedAt: nil, completedAt: nil, estimatedHours: nil,
                recurring: true, baseCadenceSeconds: cadence, cadenceMore: nil, cadenceLess: nil,
                instance: .init(startedAt: instanceStart, actualCadenceSeconds: cadence, snoozed: false),
                followUps: [], parentTaskId: nil, prompts: [], soundSeed: nil, actionLog: [])
    }

    func test_halfElapsedIsHalfRatio() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let t = task(instanceStart: now.addingTimeInterval(-50), cadence: 100)
        XCTAssertEqual(Urgency.ratio(t, now: now), 0.5, accuracy: 0.0001)
    }

    func test_overdueClampsTier() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let t = task(instanceStart: now.addingTimeInterval(-200), cadence: 100)
        XCTAssertTrue(Urgency.ratio(t, now: now) >= 1.0)
        XCTAssertEqual(Urgency.tier(for: Urgency.ratio(t, now: now)), .overdue)
    }

    func test_tierBoundaries() {
        XCTAssertEqual(Urgency.tier(for: 0.0), .calm)
        XCTAssertEqual(Urgency.tier(for: 0.74), .calm)
        XCTAssertEqual(Urgency.tier(for: 0.75), .soon)
        XCTAssertEqual(Urgency.tier(for: 0.94), .soon)
        XCTAssertEqual(Urgency.tier(for: 0.95), .due)
        XCTAssertEqual(Urgency.tier(for: 0.99), .due)
        XCTAssertEqual(Urgency.tier(for: 1.0), .overdue)
    }
}
