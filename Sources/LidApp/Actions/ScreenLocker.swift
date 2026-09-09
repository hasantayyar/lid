import ApplicationServices
import Foundation
import LidCore

public struct CGEventScreenLocker: ScreenLocking {
    public init() {}

    public func permissionStatus() async -> PermissionStatus {
        AXIsProcessTrusted() ? .granted : .denied
    }

    public func requestPermission() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        LidLog.permissions.info("requested accessibility for lock")
    }

    public func lock() async throws {
        guard AXIsProcessTrusted() else {
            throw SensorError.unavailable
        }
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            throw SensorError.reportFailed(code: "event_source")
        }
        let keyQ: CGKeyCode = 12
        guard
            let down = CGEvent(keyboardEventSource: source, virtualKey: keyQ, keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: keyQ, keyDown: false)
        else {
            throw SensorError.reportFailed(code: "event_create")
        }
        down.flags = [.maskCommand, .maskControl]
        up.flags = [.maskCommand, .maskControl]
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
