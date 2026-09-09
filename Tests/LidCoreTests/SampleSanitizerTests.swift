import XCTest
@testable import LidCore

final class SampleSanitizerTests: XCTestCase {
    func testFirstSamplePassesThrough() {
        var sanitizer = SampleSanitizer(maxStepDegrees: 40)
        let sample = LidAngleSample(degrees: 90, collectedAtNanoseconds: 0, quality: .valid)
        XCTAssertEqual(sanitizer.process(sample).quality, .valid)
    }

    func testImplausibleJumpIsSuspectUntilConfirmed() {
        var sanitizer = SampleSanitizer(maxStepDegrees: 40)
        _ = sanitizer.process(LidAngleSample(degrees: 90, collectedAtNanoseconds: 0, quality: .valid))
        let jumped = sanitizer.process(LidAngleSample(degrees: 20, collectedAtNanoseconds: 1, quality: .valid))
        XCTAssertEqual(jumped.quality, .suspect)
        let confirmed = sanitizer.process(LidAngleSample(degrees: 18, collectedAtNanoseconds: 2, quality: .valid))
        XCTAssertEqual(confirmed.quality, .valid)
        XCTAssertEqual(confirmed.degrees, 18)
    }

    func testSmallStepsStayValid() {
        var sanitizer = SampleSanitizer(maxStepDegrees: 40)
        _ = sanitizer.process(LidAngleSample(degrees: 90, collectedAtNanoseconds: 0, quality: .valid))
        let next = sanitizer.process(LidAngleSample(degrees: 80, collectedAtNanoseconds: 1, quality: .valid))
        XCTAssertEqual(next.quality, .valid)
    }

    func testInvalidSamplesAreNotUsedAsAnchor() {
        var sanitizer = SampleSanitizer(maxStepDegrees: 40)
        _ = sanitizer.process(LidAngleSample(degrees: 90, collectedAtNanoseconds: 0, quality: .valid))
        let invalid = sanitizer.process(LidAngleSample(degrees: 10, collectedAtNanoseconds: 1, quality: .invalid))
        XCTAssertEqual(invalid.quality, .invalid)
        let next = sanitizer.process(LidAngleSample(degrees: 88, collectedAtNanoseconds: 2, quality: .valid))
        XCTAssertEqual(next.quality, .valid)
    }
}
