import XCTest
import SwiftData
@testable import ForgetMeNot

final class EntityRoundTripTests: XCTestCase {
    @MainActor
    func test_insertAndFetch() throws {
        let container = try FMNModelContainer.inMemory()
        let ctx = container.mainContext
        let e = TaskEntity(id: "abc", title: "Test")
        ctx.insert(e)
        try ctx.save()
        let fetched = try ctx.fetch(FetchDescriptor<TaskEntity>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.title, "Test")
    }
}
