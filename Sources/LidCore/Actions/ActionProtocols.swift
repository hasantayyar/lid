public struct ActionContext: Sendable {
    public var settings: AppSettings
    public var foregroundBundleID: String?

    public init(settings: AppSettings, foregroundBundleID: String? = nil) {
        self.settings = settings
        self.foregroundBundleID = foregroundBundleID
    }
}

public protocol AutomationAction: Sendable {
    var id: ActionID { get }
    func availability() async -> ActionAvailability
    func execute(context: ActionContext) async -> ActionResult
    func reset(context: ActionContext) async
}

public protocol ScreenLocking: Sendable {
    func permissionStatus() async -> PermissionStatus
    func lock() async throws
}

public protocol MediaControlling: Sendable {
    func playbackState() async -> PlaybackState
    func pauseIfPlaying() async -> ActionResult
}

public protocol PrivacyOverlayControlling: Sendable {
    func show() async
    func hide() async
    func isVisible() async -> Bool
}
