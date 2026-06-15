import XCTest
@testable import ForgetMeNot

final class ExportEnvelopeTests: XCTestCase {
    func test_roundTripsWrapper() throws {
        let url = Bundle(for: Self.self).url(forResource: "web-export", withExtension: "json")!
        let data = try Data(contentsOf: url)
        let env = try FMNJSON.decoder.decode(ExportEnvelope.self, from: data)
        XCTAssertEqual(env.version, 1)
        XCTAssertEqual(env.tasks.count, 1)
        XCTAssertNotNil(env.settings)
        let re = try FMNJSON.encoder.encode(env)
        let env2 = try FMNJSON.decoder.decode(ExportEnvelope.self, from: re)
        XCTAssertEqual(env2.tasks, env.tasks)
    }
}
