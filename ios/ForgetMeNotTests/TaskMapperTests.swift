import XCTest
@testable import ForgetMeNot

final class TaskMapperTests: XCTestCase {
    func test_dtoToEntityToDtoIsLossless() throws {
        let url = Bundle(for: Self.self).url(forResource: "web-export", withExtension: "json")!
        let env = try FMNJSON.decoder.decode(ExportEnvelope.self, from: try Data(contentsOf: url))
        let dto = env.tasks[0]
        let entity = TaskMapper.entity(from: dto)
        let back = TaskMapper.dto(from: entity)
        XCTAssertEqual(back, dto)
    }
}
