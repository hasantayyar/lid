/// Parses the undocumented lid-angle feature report.
///
/// Verified layout on Mac16,8: 3 bytes, report ID 1, little-endian UInt16
/// degrees immediately after the report ID. Do not log `bytes`.
public enum HIDAngleReportParser: Sendable {
    public static let featureReportID: UInt8 = 1
    public static let minimumLength = 3
    public static let suspectAboveDegrees: Double = 180
    public static let invalidAboveDegrees: Double = 360

    public struct Parsed: Sendable, Equatable {
        public var rawValue: UInt16
        public var degrees: Double
        public var quality: SampleQuality
    }

    public enum ParseError: Error, Sendable, Equatable, CustomStringConvertible {
        case tooShort(length: Int)
        case unexpectedReportID(UInt8)
        case implausible(rawValue: UInt16)

        public var description: String {
            switch self {
            case .tooShort(let length):
                "hid_report_too_short:\(length)"
            case .unexpectedReportID(let reportID):
                "hid_unexpected_report_id:\(reportID)"
            case .implausible(let rawValue):
                "hid_implausible_angle:\(rawValue)"
            }
        }
    }

    public static func parse(_ bytes: [UInt8]) -> Result<Parsed, ParseError> {
        bytes.withUnsafeBufferPointer(parse)
    }

    public static func parse(_ bytes: UnsafeBufferPointer<UInt8>) -> Result<Parsed, ParseError> {
        guard bytes.count >= minimumLength else {
            return .failure(.tooShort(length: bytes.count))
        }
        guard let reportID = bytes.first else {
            return .failure(.tooShort(length: 0))
        }
        guard reportID == featureReportID else {
            return .failure(.unexpectedReportID(reportID))
        }
        let rawValue = UInt16(bytes[1]) | (UInt16(bytes[2]) << 8)
        let degrees = Double(rawValue)
        if degrees > invalidAboveDegrees {
            return .failure(.implausible(rawValue: rawValue))
        }
        let quality: SampleQuality = degrees > suspectAboveDegrees ? .suspect : .valid
        return .success(Parsed(rawValue: rawValue, degrees: degrees, quality: quality))
    }
}
