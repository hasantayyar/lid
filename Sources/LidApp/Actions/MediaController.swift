import AppKit
import Foundation
import LidCore

public actor AppleScriptMediaController: MediaControlling {
    private let supported = [
        "com.apple.Music": "Music",
        "com.spotify.client": "Spotify",
    ]

    public init() {}

    public func playbackState() async -> PlaybackState {
        var sawUnknown = false
        for (bundleID, name) in supported {
            guard await isRunning(bundleID) else { continue }
            switch queryState(appName: name) {
            case .playing:
                return .playing
            case .unknown:
                sawUnknown = true
            case .paused, .stopped:
                continue
            }
        }
        return sawUnknown ? .unknown : .stopped
    }

    public func pauseIfPlaying() async -> ActionResult {
        var unknown = false
        var paused = false
        for (bundleID, name) in supported {
            guard await isRunning(bundleID) else { continue }
            switch queryState(appName: name) {
            case .playing:
                if pause(appName: name) {
                    paused = true
                } else {
                    unknown = true
                }
            case .unknown:
                unknown = true
            case .paused, .stopped:
                continue
            }
        }
        if paused { return .succeeded }
        if unknown { return .skipped(.mediaStateUnknown) }
        return .skipped(.notPlaying)
    }

    private func isRunning(_ bundleID: String) async -> Bool {
        await MainActor.run {
            NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == bundleID }
        }
    }

    private func queryState(appName: String) -> PlaybackState {
        let source = """
        tell application "\(appName)"
            if player state is playing then
                return "playing"
            else if player state is paused then
                return "paused"
            else
                return "stopped"
            end if
        end tell
        """
        switch run(source) {
        case "playing": return .playing
        case "paused": return .paused
        case "stopped": return .stopped
        default: return .unknown
        }
    }

    private func pause(appName: String) -> Bool {
        let source = """
        tell application "\(appName)"
            if player state is playing then
                pause
                return "paused"
            end if
            return "skipped"
        end tell
        """
        return run(source) == "paused"
    }

    private func run(_ source: String) -> String? {
        let script = NSAppleScript(source: source)
        var error: NSDictionary?
        let result = script?.executeAndReturnError(&error)
        if error != nil {
            return nil
        }
        return result?.stringValue
    }
}
