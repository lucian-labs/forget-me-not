import XCTest
@testable import ForgetMeNot

final class ISO8601Tests: XCTestCase {
    func test_decodesAndReencodesJSToISOString() throws {
        // JS: new Date("2026-06-15T12:34:56.789Z").toISOString() === "2026-06-15T12:34:56.789Z"
        let json = #"{"at":"2026-06-15T12:34:56.789Z"}"#.data(using: .utf8)!
        struct Box: Codable, Equatable { var at: Date }
        let decoded = try FMNJSON.decoder.decode(Box.self, from: json)
        let reencoded = try FMNJSON.encoder.encode(decoded)
        let s = String(data: reencoded, encoding: .utf8)!
        XCTAssertTrue(s.contains("2026-06-15T12:34:56.789Z"), s)
    }
}
