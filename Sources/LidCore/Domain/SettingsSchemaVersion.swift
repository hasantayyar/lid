public enum SettingsSchemaVersion: Int, Sendable, Codable, Equatable, Comparable {
    case v1 = 1

    public static let current = SettingsSchemaVersion.v1

    public static func < (lhs: SettingsSchemaVersion, rhs: SettingsSchemaVersion) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
