import Foundation

public struct RuleResolver: Sendable {
    public init() {}

    public func resolve(
        settings: AppSettings,
        snooze: SnoozeState,
        now: Date,
        calendar: Calendar,
        foregroundBundleID: String?
    ) -> RuleResolution {
        if !settings.automationEnabled {
            return .inactiveGlobal
        }
        if snooze.isActive(at: now) {
            return .snoozed
        }
        if let foregroundBundleID, settings.applicationExclusions.contains(foregroundBundleID) {
            return .excludedApplication(bundleID: foregroundBundleID)
        }
        let enabledSchedules = settings.schedules.filter(\.enabled)
        if !enabledSchedules.isEmpty {
            let matching = enabledSchedules.contains { $0.contains(date: now, calendar: calendar) }
            if !matching {
                return .outsideSchedule
            }
            return .active(reason: "Inside a scheduled window")
        }
        return .active(reason: "Default rule")
    }
}
