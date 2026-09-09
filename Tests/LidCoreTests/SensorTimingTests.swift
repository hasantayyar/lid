import XCTest
@testable import LidCore

final class SensorTimingTests: XCTestCase {
    func testBackoffCapsAtLastDelay() {
        let timing = SensorTiming.production
        XCTAssertEqual(timing.backoffDelay(forAttempt: 0), .seconds(1))
        XCTAssertEqual(timing.backoffDelay(forAttempt: 4), .seconds(15))
        XCTAssertEqual(timing.backoffDelay(forAttempt: 99), .seconds(15))
    }

    func testNanosecondCount() {
        XCTAssertEqual(Duration.milliseconds(100).nanosecondCount, 100_000_000)
        XCTAssertEqual(Duration.seconds(2).nanosecondCount, 2_000_000_000)
    }
}
