public enum ActionResult: Sendable, Equatable {
    case succeeded
    case submittedUnverified
    case skipped(SkipReason)
    case denied(PermissionKind)
    case unsupported
    case failed(code: String)
}

public enum SkipReason: String, Sendable, Codable, Equatable {
    case disabled
    case snoozed
    case excludedApplication
    case outsideSchedule
    case mediaStateUnknown
    case notPlaying
    case alreadyApplied
    case staleSample
    case suspectSample
    case invalidSample
    case cooldown
    case notArmed
}

public enum PermissionKind: String, Sendable, Codable, Equatable {
    case accessibility
    case appleEvents
}

public enum PermissionStatus: String, Sendable, Codable, Equatable {
    case granted
    case denied
    case notDetermined
}

public enum ActionAvailability: String, Sendable, Codable, Equatable {
    case ready
    case unavailable
    case permissionRequired
    case unsupported
}

public enum PlaybackState: String, Sendable, Codable, Equatable {
    case playing
    case paused
    case stopped
    case unknown
}
