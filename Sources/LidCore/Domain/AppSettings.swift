import Foundation

public struct ThresholdActionSettings: Sendable, Hashable, Codable, Equatable {
    public var enabled: Bool
    public var thresholdDegrees: Double

    public init(enabled: Bool, thresholdDegrees: Double) {
        self.enabled = enabled
        self.thresholdDegrees = thresholdDegrees
    }
}

public struct AppSettings: Sendable, Hashable, Codable, Equatable {
    public static let minimumThreshold = 5.0
    public static let maximumThreshold = 135.0
    public static let minimumSeparation = 10.0

    public var schemaVersion: SettingsSchemaVersion
    public var automationEnabled: Bool
    public var launchAtLogin: Bool
    public var showAngleInMenuBar: Bool
    public var startEnabledAfterLaunch: Bool
    public var privacy: ThresholdActionSettings
    public var lock: ThresholdActionSettings
    public var media: ThresholdActionSettings
    public var applicationExclusions: [String]
    public var schedules: [ScheduleWindow]
    public var completedOnboarding: Bool

    public init(
        schemaVersion: SettingsSchemaVersion = .current,
        automationEnabled: Bool = true,
        launchAtLogin: Bool = false,
        showAngleInMenuBar: Bool = true,
        startEnabledAfterLaunch: Bool = true,
        privacy: ThresholdActionSettings = ThresholdActionSettings(enabled: true, thresholdDegrees: 60),
        lock: ThresholdActionSettings = ThresholdActionSettings(enabled: true, thresholdDegrees: 20),
        media: ThresholdActionSettings = ThresholdActionSettings(enabled: true, thresholdDegrees: 60),
        applicationExclusions: [String] = [],
        schedules: [ScheduleWindow] = [],
        completedOnboarding: Bool = false
    ) throws {
        self.schemaVersion = schemaVersion
        self.automationEnabled = automationEnabled
        self.launchAtLogin = launchAtLogin
        self.showAngleInMenuBar = showAngleInMenuBar
        self.startEnabledAfterLaunch = startEnabledAfterLaunch
        self.privacy = privacy
        self.lock = lock
        self.media = media
        self.applicationExclusions = applicationExclusions
        self.schedules = schedules
        self.completedOnboarding = completedOnboarding
        try validate()
    }

    public static var `default`: AppSettings {
        do {
            return try AppSettings()
        } catch {
            preconditionFailure("default settings must be valid")
        }
    }

    public func validate() throws {
        try Self.validateThreshold(privacy.thresholdDegrees, name: "privacy")
        try Self.validateThreshold(lock.thresholdDegrees, name: "lock")
        try Self.validateThreshold(media.thresholdDegrees, name: "media")
        if privacy.enabled && lock.enabled {
            let gap = privacy.thresholdDegrees - lock.thresholdDegrees
            if gap < Self.minimumSeparation {
                throw SettingsValidationError.lockNotSeparatedFromPrivacy(
                    privacy: privacy.thresholdDegrees,
                    lock: lock.thresholdDegrees
                )
            }
        }
        if applicationExclusions.contains(where: { $0.isEmpty || $0.contains("/") }) {
            throw SettingsValidationError.invalidBundleIdentifier
        }
    }

    public func threshold(for action: ActionID) -> Double? {
        switch action {
        case .privacyOverlay: privacy.enabled ? privacy.thresholdDegrees : nil
        case .mediaPause: media.enabled ? media.thresholdDegrees : nil
        case .lock: lock.enabled ? lock.thresholdDegrees : nil
        }
    }

    public var nextDownwardAction: (ActionID, Double)? {
        let pairs: [(ActionID, Double)] = ActionIntentOrdering.applyOrder.compactMap { id in
            guard let threshold = threshold(for: id) else { return nil }
            return (id, threshold)
        }
        return pairs.max(by: { $0.1 < $1.1 })
    }

    private static func validateThreshold(_ value: Double, name: String) throws {
        guard (minimumThreshold...maximumThreshold).contains(value) else {
            throw SettingsValidationError.thresholdOutOfRange(name: name, value: value)
        }
    }
}

public enum SettingsValidationError: Error, Sendable, Equatable, CustomStringConvertible {
    case thresholdOutOfRange(name: String, value: Double)
    case lockNotSeparatedFromPrivacy(privacy: Double, lock: Double)
    case invalidBundleIdentifier
    case unsupportedSchema(Int)
    case payloadTooLarge
    case invalidJSON

    public var description: String {
        switch self {
        case .thresholdOutOfRange(let name, let value):
            "threshold_out_of_range:\(name):\(value)"
        case .lockNotSeparatedFromPrivacy:
            "lock_not_separated_from_privacy"
        case .invalidBundleIdentifier:
            "invalid_bundle_identifier"
        case .unsupportedSchema(let value):
            "unsupported_schema:\(value)"
        case .payloadTooLarge:
            "payload_too_large"
        case .invalidJSON:
            "invalid_json"
        }
    }
}
