import XCTest
@testable import ForgetMeNot

final class CadenceTests: XCTestCase {
    func test_withinBounds() {
        var rng = SeededRNG(seed: 42)
        for _ in 0..<100 {
            let v = Cadence.randomized(base: 1000, more: 200, less: 300, using: &rng)
            XCTAssertGreaterThanOrEqual(v, 700)
            XCTAssertLessThanOrEqual(v, 1200)
        }
    }

    func test_nilVarianceReturnsBase() {
        var rng = SeededRNG(seed: 1)
        XCTAssertEqual(Cadence.randomized(base: 1000, more: nil, less: nil, using: &rng), 1000)
    }
}
