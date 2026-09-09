import AppKit
import SwiftUI

@MainActor
final class LidWindowPresenter: NSObject, NSWindowDelegate {
    static let shared = LidWindowPresenter()

    private var windows: [WindowID: NSWindow] = [:]
    private var session: LidSession?

    enum WindowID: String {
        case settings
        case diagnostics
        case onboarding
    }

    func attach(_ session: LidSession) {
        self.session = session
    }

    func show(_ id: WindowID) {
        guard let session else { return }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()

        if let existing = windows[id] {
            existing.makeKeyAndOrderFront(nil)
            NSApp.arrangeInFront(nil)
            return
        }

        let hosting = NSHostingController(rootView: content(id, session: session))
        let window = NSWindow(contentViewController: hosting)
        window.title = title(id)
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.setContentSize(size(id))
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.identifier = NSUserInterfaceItemIdentifier(id.rawValue)
        window.center()
        window.makeKeyAndOrderFront(nil)
        windows[id] = window
    }

    func close(_ id: WindowID) {
        windows[id]?.performClose(nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        windows = windows.filter { $0.value !== window }
        if windows.isEmpty {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    private func title(_ id: WindowID) -> String {
        switch id {
        case .settings: "Lid Settings"
        case .diagnostics: "Lid Diagnostics"
        case .onboarding: "Welcome to Lid"
        }
    }

    private func size(_ id: WindowID) -> NSSize {
        switch id {
        case .settings: NSSize(width: 640, height: 540)
        case .diagnostics: NSSize(width: 560, height: 480)
        case .onboarding: NSSize(width: 500, height: 360)
        }
    }

    @ViewBuilder
    private func content(_ id: WindowID, session: LidSession) -> some View {
        switch id {
        case .settings:
            SettingsRootView(session: session)
        case .diagnostics:
            DiagnosticsView(session: session)
        case .onboarding:
            OnboardingView(session: session)
        }
    }
}
