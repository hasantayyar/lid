public actor ActionExecutor {
    private let overlay: any PrivacyOverlayControlling
    private let locker: any ScreenLocking
    private let media: any MediaControlling

    public init(
        overlay: any PrivacyOverlayControlling,
        locker: any ScreenLocking,
        media: any MediaControlling
    ) {
        self.overlay = overlay
        self.locker = locker
        self.media = media
    }

    public func execute(_ intents: [ActionIntent], context: ActionContext) async -> [ActionIntent: ActionResult] {
        var results: [ActionIntent: ActionResult] = [:]
        for intent in intents {
            switch intent {
            case .apply(let id):
                results[intent] = await apply(id, context: context)
            case .reset(let id):
                await reset(id, context: context)
                results[intent] = .succeeded
            }
        }
        return results
    }

    private func apply(_ id: ActionID, context: ActionContext) async -> ActionResult {
        switch id {
        case .privacyOverlay:
            await overlay.show()
            return .succeeded
        case .mediaPause:
            let result = await media.pauseIfPlaying()
            if result == .skipped(.mediaStateUnknown) {
                LidLog.actions.info("media_state_unknown")
            }
            return result
        case .lock:
            let status = await locker.permissionStatus()
            guard status == .granted else {
                LidLog.permissions.info("lock denied accessibility")
                return .denied(.accessibility)
            }
            do {
                try await locker.lock()
                return .submittedUnverified
            } catch {
                return .failed(code: "lock_failed")
            }
        }
    }

    private func reset(_ id: ActionID, context: ActionContext) async {
        switch id {
        case .privacyOverlay:
            await overlay.hide()
        case .mediaPause, .lock:
            break
        }
    }
}
