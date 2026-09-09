import LidCore
import SwiftUI

struct OnboardingView: View {
    @Bindable var session: LidSession
    @State private var page = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title2)
            Text(bodyText)
                .foregroundStyle(.secondary)
            if page == 1 {
                Text(session.sensorStateText)
                    .font(.headline)
                if let angle = session.filteredAngle, session.sensorState == .available {
                    Text("Current angle: \(Int(angle.rounded()))°")
                }
            }
            if page == 2 {
                Toggle("Enable privacy overlay at 60°", isOn: enabled(\.privacy))
                Toggle("Enable lock at 20°", isOn: enabled(\.lock))
                Toggle("Pause confirmed media", isOn: enabled(\.media))
            }
            if page == 3 {
                Button("Test privacy overlay") {
                    Task { await session.testOverlay() }
                }
                Button("Test lock") {
                    Task { await session.testLock() }
                }
                Text("Lock asks for Accessibility first. Deny it if you do not want lock.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            HStack {
                if page > 0 {
                    Button("Back") { page -= 1 }
                }
                Spacer()
                if page < 4 {
                    Button("Continue") { page += 1 }
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button("Done") {
                        Task {
                            await session.finishOnboarding()
                            session.showOnboarding = false
                            session.closeOnboarding()
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(24)
        .frame(width: 460, height: 320, alignment: .topLeading)
    }

    private var title: String {
        switch page {
        case 0: "Lid needs a compatible MacBook"
        case 1: "Sensor check"
        case 2: "Choose actions"
        case 3: "Try the actions"
        default: "Review"
        }
    }

    private var bodyText: String {
        switch page {
        case 0:
            "Lid uses an undocumented lid-angle sensor. It is not available on every Mac. If this Mac has no sensor, Lid stays safe and does not invent an angle."
        case 1:
            "This page shows the live reading. Actions are still off until you finish."
        case 2:
            "You can change these later. Lock uses the standard Control-Command-Q shortcut after Accessibility is granted."
        case 3:
            "The overlay never captures the screen. Lock is not sent unless you press the test button."
        default:
            "Privacy \(session.settings.privacy.enabled ? "on" : "off") at \(Int(session.settings.privacy.thresholdDegrees))°. Lock \(session.settings.lock.enabled ? "on" : "off") at \(Int(session.settings.lock.thresholdDegrees))°. Media \(session.settings.media.enabled ? "on" : "off")."
        }
    }

    private func enabled(_ path: WritableKeyPath<AppSettings, ThresholdActionSettings>) -> Binding<Bool> {
        Binding(
            get: { session.settings[keyPath: path].enabled },
            set: { value in
                Task { await session.updateSettings { $0[keyPath: path].enabled = value } }
            }
        )
    }
}
