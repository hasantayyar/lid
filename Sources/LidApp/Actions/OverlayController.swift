import AppKit
import LidCore

@MainActor
final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

public final class OverlayController: PrivacyOverlayControlling, @unchecked Sendable {
    public init() {
        Task { @MainActor in
            OverlayControllerMain.shared.prepare()
        }
    }

    public func show() async {
        await OverlayControllerMain.shared.show()
    }

    public func hide() async {
        await OverlayControllerMain.shared.hide()
    }

    public func isVisible() async -> Bool {
        await OverlayControllerMain.shared.isVisible()
    }
}

@MainActor
private final class OverlayControllerMain {
    static let shared = OverlayControllerMain()
    private var panels: [ObjectIdentifier: OverlayPanel] = [:]
    private var observer: NSObjectProtocol?

    func prepare() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                OverlayControllerMain.shared.reconcileIfVisible()
            }
        }
    }

    func show() {
        hide()
        prepare()
        for screen in NSScreen.screens {
            let panel = OverlayPanel(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.level = .screenSaver
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            panel.isOpaque = true
            panel.backgroundColor = .black
            panel.hasShadow = false
            panel.hidesOnDeactivate = false
            panel.ignoresMouseEvents = false
            panel.animationBehavior = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? .none : .utilityWindow
            panel.contentView = OverlayView(frame: screen.frame)
            panel.orderFrontRegardless()
            panels[ObjectIdentifier(screen)] = panel
        }
    }

    func hide() {
        let existing = Array(panels.values)
        panels.removeAll()
        for panel in existing {
            panel.orderOut(nil)
            panel.close()
        }
    }

    func isVisible() -> Bool {
        !panels.isEmpty
    }

    private func reconcileIfVisible() {
        guard !panels.isEmpty else { return }
        show()
    }
}

@MainActor
private final class OverlayView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill()
        dirtyRect.fill()
    }
}
