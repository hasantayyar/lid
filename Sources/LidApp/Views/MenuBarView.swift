import AppKit
import LidCore
import SwiftUI

struct MenuBarLabel: View {
    var session: LidSession

    var body: some View {
        Text(session.menuAngleText)
    }
}

struct MenuBarView: View {
    @Bindable var session: LidSession

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            controls
            Divider()
            Text(session.resolutionTitle)
                .font(.callout)
                .foregroundStyle(.secondary)
            Text(session.nextActionText)
                .font(.callout)
            if session.snooze.isActive(at: Date()) {
                Text(snoozeText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Divider()
            Button("Open settings") { session.openSettings() }
            Button("Diagnostics") { session.openDiagnostics() }
            Button("Quit Lid") {
                Task {
                    await session.shutdown()
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(14)
        .frame(width: 280, alignment: .leading)
        .task {
            await session.start()
            if session.showOnboarding {
                session.openOnboarding()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let angle = session.filteredAngle, session.sensorState == .available {
                Text("\(Int(angle.rounded()))°")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            } else {
                Text(session.sensorStateText)
                    .font(.headline)
            }
            Text("Sensor: \(session.sensorStateText)")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("Automation: \(session.automationState.rawValue.capitalized)")
                .font(.callout)
        }
        .accessibilityElement(children: .combine)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button("On") {
                    Task { await session.setAutomationEnabled(true) }
                }
                .disabled(session.automationState == .on && session.settings.automationEnabled)
                Button("Off") {
                    Task { await session.setAutomationEnabled(false) }
                }
                Menu("Snooze") {
                    ForEach(SnoozeOption.allCases, id: \.title) { option in
                        Button(option.title) {
                            Task { await session.applySnooze(option) }
                        }
                    }
                    if session.snooze.isConfigured {
                        Button("Resume now") {
                            Task { await session.applySnooze(nil) }
                        }
                    }
                }
            }
        }
    }

    private var snoozeText: String {
        if session.snooze.isManual {
            return "Snoozed until you resume"
        }
        if let end = session.snooze.endsAt {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Snoozed until \(formatter.string(from: end))"
        }
        return "Snoozed"
    }
}
