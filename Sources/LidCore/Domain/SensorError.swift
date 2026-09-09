public enum SensorError: Error, Sendable, Equatable, CustomStringConvertible {
    case alreadyStarted
    case hidSubsystemUnavailable
    case unavailable
    case deviceOpenFailed(code: String)
    case reportFailed(code: String)
    case invalidReport(code: String)

    public var description: String {
        switch self {
        case .alreadyStarted:
            "already_started"
        case .hidSubsystemUnavailable:
            "hid_subsystem_unavailable"
        case .unavailable:
            "sensor_unavailable"
        case .deviceOpenFailed(let code):
            "device_open_failed:\(code)"
        case .reportFailed(let code):
            "report_failed:\(code)"
        case .invalidReport(let code):
            "invalid_report:\(code)"
        }
    }

    public var sanitizedCode: String {
        description
    }
}
