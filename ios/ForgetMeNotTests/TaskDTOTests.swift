import XCTest
@testable import ForgetMeNot

final class TaskDTOTests: XCTestCase {
    private func fixture() throws -> Data {
        let url = Bundle(for: Self.self).url(forResource: "web-export", withExtension: "json")!
        return try Data(contentsOf: url)
    }

    func test_decodesWebTaskShape() throws {
        let env = try FMNJSON.decoder.decode(ExportEnvelope.self, from: fixture())
        let t = try XCTUnwrap(env.tasks.first)
        XCTAssertEqual(t.id, "11111111-1111-1111-1111-111111111111")
        XCTAssertEqual(t.title, "Flip the laundry")
        XCTAssertEqual(t.recurring, true)
        XCTAssertEqual(t.baseCadenceSeconds, 2700)
        XCTAssertEqual(t.instance?.actualCadenceSeconds, 2850)
        XCTAssertEqual(t.followUps.first?.title, "Fold the laundry")
        XCTAssertEqual(t.soundSeed, "laundry-7")
        XCTAssertEqual(t.actionLog.first?.action, .reset)
        XCTAssertNil(t.dueDate)
    }

    func test_nullableFieldsReencodeAsExplicitNull() throws {
        let env = try FMNJSON.decoder.decode(ExportEnvelope.self, from: fixture())
        let data = try FMNJSON.encoder.encode(env.tasks[0])
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        // Web keeps nullable keys present as null; assert the key exists and is NSNull.
        XCTAssertTrue(obj.keys.contains("dueDate"))
        XCTAssertTrue(obj["dueDate"] is NSNull)
        XCTAssertTrue(obj["parentTaskId"] is NSNull)
    }
}
