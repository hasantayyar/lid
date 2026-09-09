import XCTest
@testable import LidCore

final class HIDAngleReportParserTests: XCTestCase {
    func testParsesLittleEndianDegreesFromVerifiedLayout() {
        let report: [UInt8] = [0x01, 0x81, 0x00]
        let parsed = try? HIDAngleReportParser.parse(report).get()
        XCTAssertEqual(parsed?.rawValue, 129)
        XCTAssertEqual(parsed?.degrees, 129)
        XCTAssertEqual(parsed?.quality, .valid)
    }

    func testParsesHighByte() {
        let report: [UInt8] = [0x01, 0x2C, 0x01]
        let parsed = try? HIDAngleReportParser.parse(report).get()
        XCTAssertEqual(parsed?.rawValue, 300)
        XCTAssertEqual(parsed?.degrees, 300)
        XCTAssertEqual(parsed?.quality, .suspect)
    }

    func testRejectsShortReport() {
        switch HIDAngleReportParser.parse([0x01, 0x10]) {
        case .failure(.tooShort(let length)):
            XCTAssertEqual(length, 2)
        default:
            XCTFail("expected tooShort")
        }
    }

    func testRejectsEmptyReport() {
        switch HIDAngleReportParser.parse([]) {
        case .failure(.tooShort(let length)):
            XCTAssertEqual(length, 0)
        default:
            XCTFail("expected tooShort")
        }
    }

    func testRejectsUnexpectedReportID() {
        switch HIDAngleReportParser.parse([0x02, 0x10, 0x00]) {
        case .failure(.unexpectedReportID(let reportID)):
            XCTAssertEqual(reportID, 2)
        default:
            XCTFail("expected unexpectedReportID")
        }
    }

    func testRejectsImplausibleAngle() {
        switch HIDAngleReportParser.parse([0x01, 0x6D, 0x01]) {
        case .failure(.implausible(let raw)):
            XCTAssertEqual(raw, 365)
        default:
            XCTFail("expected implausible")
        }
    }

    func testClosedLidIsValidZero() {
        let parsed = try? HIDAngleReportParser.parse([0x01, 0x00, 0x00]).get()
        XCTAssertEqual(parsed?.degrees, 0)
        XCTAssertEqual(parsed?.quality, .valid)
    }

    func testErrorDescriptionsDoNotContainPayloadBytes() {
        let errors: [HIDAngleReportParser.ParseError] = [
            .tooShort(length: 1),
            .unexpectedReportID(2),
            .implausible(rawValue: 400),
        ]
        for error in errors {
            XCTAssertFalse(error.description.contains("01 81"))
            XCTAssertFalse(error.description.contains("0x01,0x81"))
        }
    }
}
