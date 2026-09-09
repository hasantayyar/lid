public enum SensorState: String, Sendable, Codable, Equatable {
    case stopped
    case available
    case unavailable
    case reconnecting
    case permissionBlocked
}
