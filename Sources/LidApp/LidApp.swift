import AppKit
import SwiftUI

@main
struct LidApp: App {
    @State private var session = LidSession()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(session: session)
        } label: {
            MenuBarLabel(session: session)
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class LidAppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        // Overlay cleanup is also handled by LidSession.shutdown from Quit.
    }
}
