public actor FakeScreenLocker: ScreenLocking {
    public var status: PermissionStatus = .granted
    public var lockCount = 0
    public var shouldFail = false

    public init() {}

    public func permissionStatus() async -> PermissionStatus { status }

    public func lock() async throws {
        if status != .granted {
            throw SensorError.unavailable
        }
        if shouldFail {
            throw SensorError.reportFailed(code: "lock_failed")
        }
        lockCount += 1
    }
}

public actor FakeMediaController: MediaControlling {
    public var state: PlaybackState = .playing
    public var pauseCount = 0

    public init(state: PlaybackState = .playing) {
        self.state = state
    }

    public func playbackState() async -> PlaybackState { state }

    public func pauseIfPlaying() async -> ActionResult {
        switch state {
        case .playing:
            pauseCount += 1
            state = .paused
            return .succeeded
        case .unknown:
            return .skipped(.mediaStateUnknown)
        case .paused, .stopped:
            return .skipped(.notPlaying)
        }
    }
}

public actor FakeOverlayController: PrivacyOverlayControlling {
    public var visible = false
    public var showCount = 0
    public var hideCount = 0

    public init() {}

    public func show() async {
        visible = true
        showCount += 1
    }

    public func hide() async {
        if visible {
            hideCount += 1
        }
        visible = false
    }

    public func isVisible() async -> Bool { visible }
}
