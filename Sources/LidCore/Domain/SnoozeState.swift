import Foundation

public enum SnoozeOption: Sendable, Equatable, CaseIterable {
    case minutes5
    case minutes15
    case minutes60
    case untilManualResume

    public var title: String {
        switch self {
        case .minutes5: "Snooze 5 minutes"
        case .minutes15: "Snooze 15 minutes"
        case .minutes60: "Snooze 1 hour"
        case .untilManualResume: "Snooze until I resume"
        }
    }

    public var duration: Duration? {
        switch self {
        case .minutes5: .seconds(5 * 60)
        case .minutes15: .seconds(15 * 60)
        case .minutes60: .seconds(60 * 60)
        case .untilManualResume: nil
        }
    }
}

public struct SnoozeState: Sendable, Hashable, Codable, Equatable {
    public var endsAt: Date?
    public var isManual: Bool

    public init(endsAt: Date?, isManual: Bool) {
        self.endsAt = endsAt
        self.isManual = isManual
    }

    public static let inactive = SnoozeState(endsAt: nil, isManual: false)

    public var isConfigured: Bool {
        isManual || endsAt != nil
    }

    public func isActive(at date: Date) -> Bool {
        if isManual { return true }
        guard let endsAt else { return false }
        return date < endsAt
    }

    public static func starting(_ option: SnoozeOption, now: Date) -> SnoozeState {
        switch option {
        case .untilManualResume:
            return SnoozeState(endsAt: nil, isManual: true)
        case .minutes5, .minutes15, .minutes60:
            let seconds = option.duration?.nanosecondCount ?? 0
            let end = now.addingTimeInterval(TimeInterval(seconds) / 1_000_000_000)
            return SnoozeState(endsAt: end, isManual: false)
        }
    }
}
