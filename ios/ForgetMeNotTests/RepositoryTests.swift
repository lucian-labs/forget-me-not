import XCTest
import SwiftData
@testable import ForgetMeNot

final class RepositoryTests: XCTestCase {
    @MainActor
    private func makeRepo() throws -> SwiftDataTaskRepository {
        SwiftDataTaskRepository(container: try FMNModelContainer.inMemory())
    }

    private func sample(_ id: String) -> TaskDTO {
        TaskDTO(id: id, title: "t-\(id)", description: "", domain: "", tags: [], status: .open,
                priority: .normal, createdAt: Date(), updatedAt: Date(), dueDate: nil, startedAt: nil,
                completedAt: nil, estimatedHours: nil, recurring: false, baseCadenceSeconds: nil,
                cadenceMore: nil, cadenceLess: nil, instance: nil, followUps: [], parentTaskId: nil,
                prompts: [], soundSeed: nil, actionLog: [])
    }

    @MainActor
    func test_containerCreation() throws {
        let container = try FMNModelContainer.inMemory()
        XCTAssertNotNil(container)
    }

    @MainActor
    func test_insertAndFetch() throws {
        let container = try FMNModelContainer.inMemory()
        let ctx = container.mainContext
        let entity = TaskMapper.entity(from: sample("x"))
        ctx.insert(entity)
        try ctx.save()
        let fetched = try ctx.fetch(FetchDescriptor<TaskEntity>())
        XCTAssertEqual(fetched.count, 1)
    }

    @MainActor
    func test_upsertGetAllDelete() async throws {
        let repo = try makeRepo()
        try repo.upsert(sample("a"))
        try repo.upsert(sample("b"))
        XCTAssertEqual(try repo.all().count, 2)

        var a = try XCTUnwrap(repo.get("a"))
        a.title = "renamed"
        try repo.upsert(a)
        XCTAssertEqual(try repo.get("a")?.title, "renamed")   // update, not duplicate
        XCTAssertEqual(try repo.all().count, 2)

        try repo.delete("a")
        XCTAssertNil(try repo.get("a"))
        XCTAssertEqual(try repo.all().count, 1)
    }
}
