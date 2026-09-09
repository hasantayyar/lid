import XCTest
@testable import LidCore

final class HIDMatchingIsolationTests: XCTestCase {
    func testVerifiedConstantsStayInTheIOKitAdapter() {
        XCTAssertEqual(LidHIDMatching.appleVendorID, 0x05AC)
        XCTAssertEqual(LidHIDMatching.sensorHubProductID, 0x8104)
        XCTAssertEqual(LidHIDMatching.sensorUsagePage, 0x0020)
        XCTAssertEqual(LidHIDMatching.orientationUsage, 0x008A)
        XCTAssertEqual(LidHIDMatching.featureReportID, 1)
        XCTAssertEqual(HIDAngleReportParser.featureReportID, 1)
    }
}
