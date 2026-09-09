public enum RuleResolution: Sendable, Equatable {
    case inactiveGlobal
    case snoozed
    case excludedApplication(bundleID: String)
    case outsideSchedule
    case active(reason: String)

    public var allowsActions: Bool {
        if case .active = self {
            return true
        }
        return false
    }

    public var title: String {
        switch self {
        case .inactiveGlobal: "Automation is off"
        case .snoozed: "Snoozed"
        case .excludedApplication: "Foreground app is excluded"
        case .outsideSchedule: "Outside the active schedule"
        case .active(let reason): reason
        }
    }
}

public enum AutomationDisplayState: String, Sendable, Codable, Equatable {
    case on
    case snoozed
    case off
}
