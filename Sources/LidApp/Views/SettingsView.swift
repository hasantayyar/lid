import AppKit
import LidCore
import SwiftUI

struct SettingsRootView: View {
    @Bindable var session: LidSession

    var body: some View {
        TabView {
            GeneralSettingsView(session: session)
                .tabItem { Label("General", systemImage: "gearshape") }
            ActionsSettingsView(session: session)
                .tabItem { Label("Actions", systemImage: "slider.horizontal.3") }
            RulesSettingsView(session: session)
                .tabItem { Label("Rules", systemImage: "list.bullet.rectangle") }
            PrivacySettingsView(session: session)
                .tabItem { Label("Privacy and permissions", systemImage: "hand.raised") }
        }
        .frame(minWidth: 560, minHeight: 420)
        .padding()
    }
}

struct GeneralSettingsView: View {
    @Bindable var session: LidSession

    var body: some View {
        Form {
            Toggle("Enable automation", isOn: bind(\.automationEnabled))
            Toggle("Launch at login", isOn: bind(\.launchAtLogin))
            Toggle("Show angle in menu bar", isOn: bind(\.showAngleInMenuBar))
            Toggle("Start enabled after launch", isOn: bind(\.startEnabledAfterLaunch))
        }
        .formStyle(.grouped)
    }

    private func bind(_ keyPath: WritableKeyPath<AppSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { session.settings[keyPath: keyPath] },
            set: { value in
                Task { await session.updateSettings { $0[keyPath: keyPath] = value } }
            }
        )
    }
}

struct ActionsSettingsView: View {
    @Bindable var session: LidSession

    var body: some View {
        Form {
            Section("Privacy overlay") {
                Toggle("Enabled", isOn: thresholdEnabled(\.privacy))
                thresholdSlider(title: "Threshold", value: thresholdValue(\.privacy), range: 5...135)
                Button("Test overlay") {
                    Task { await session.testOverlay() }
                }
            }
            Section("Lock") {
                Toggle("Enabled", isOn: thresholdEnabled(\.lock))
                thresholdSlider(title: "Threshold", value: thresholdValue(\.lock), range: 5...135)
                Text("Lock must stay at least 10° below the privacy threshold when both are on.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("Media pause") {
                Toggle("Enabled", isOn: thresholdEnabled(\.media))
                thresholdSlider(title: "Threshold", value: thresholdValue(\.media), range: 5...135)
                Text("Pauses Music or Spotify only when playback is confirmed.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func thresholdEnabled(_ path: WritableKeyPath<AppSettings, ThresholdActionSettings>) -> Binding<Bool> {
        Binding(
            get: { session.settings[keyPath: path].enabled },
            set: { value in
                Task { await session.updateSettings { $0[keyPath: path].enabled = value } }
            }
        )
    }

    private func thresholdValue(_ path: WritableKeyPath<AppSettings, ThresholdActionSettings>) -> Binding<Double> {
        Binding(
            get: { session.settings[keyPath: path].thresholdDegrees },
            set: { value in
                Task { await session.updateSettings { $0[keyPath: path].thresholdDegrees = value } }
            }
        )
    }

    private func thresholdSlider(title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        Slider(value: value, in: range, step: 1) {
            Text("\(title): \(Int(value.wrappedValue))°")
        }
    }

}

struct RulesSettingsView: View {
    @Bindable var session: LidSession
    @State private var bundleDraft = ""

    var body: some View {
        Form {
            Section("Application exclusions") {
                ForEach(session.settings.applicationExclusions, id: \.self) { bundleID in
                    HStack {
                        Text(bundleID)
                            .monospaced()
                        Spacer()
                        Button("Remove") {
                            Task {
                                await session.updateSettings {
                                    $0.applicationExclusions.removeAll { $0 == bundleID }
                                }
                            }
                        }
                    }
                }
                HStack {
                    TextField("Bundle identifier", text: $bundleDraft)
                    Button("Add") {
                        let value = bundleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !value.isEmpty else { return }
                        Task {
                            await session.updateSettings { $0.applicationExclusions.append(value) }
                            bundleDraft = ""
                        }
                    }
                    Button("Add frontmost app") {
                        if let id = NSWorkspace.shared.frontmostApplication?.bundleIdentifier {
                            Task { await session.updateSettings { $0.applicationExclusions.append(id) } }
                        }
                    }
                }
                Text("Store bundle identifiers only. Window titles are never collected.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("Weekly schedules") {
                ForEach(session.settings.schedules) { window in
                    ScheduleRow(session: session, window: window)
                }
                Button("Add schedule") {
                    Task { await session.updateSettings { $0.schedules.append(ScheduleWindow()) } }
                }
                Text("Leave this empty to run whenever automation is on. Overnight windows are supported.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

private struct ScheduleRow: View {
    var session: LidSession
    var window: ScheduleWindow

    var body: some View {
        VStack(alignment: .leading) {
            Toggle("Enabled", isOn: Binding(
                get: { window.enabled },
                set: { value in update { $0.enabled = value } }
            ))
            HStack {
                DatePicker(
                    "Start",
                    selection: minutesBinding(\.startMinutes),
                    displayedComponents: .hourAndMinute
                )
                DatePicker(
                    "End",
                    selection: minutesBinding(\.endMinutes),
                    displayedComponents: .hourAndMinute
                )
            }
            Button("Remove") {
                Task {
                    await session.updateSettings { $0.schedules.removeAll { $0.id == window.id } }
                }
            }
        }
    }

    private func minutesBinding(_ key: WritableKeyPath<ScheduleWindow, Int>) -> Binding<Date> {
        Binding(
            get: {
                let minutes = window[keyPath: key]
                return Calendar.current.date(from: DateComponents(hour: minutes / 60, minute: minutes % 60)) ?? Date()
            },
            set: { date in
                let minutes = Calendar.current.component(.hour, from: date) * 60
                    + Calendar.current.component(.minute, from: date)
                update { $0[keyPath: key] = minutes }
            }
        )
    }

    private func update(_ mutate: @escaping (inout ScheduleWindow) -> Void) {
        Task {
            await session.updateSettings { settings in
                guard let index = settings.schedules.firstIndex(where: { $0.id == window.id }) else { return }
                mutate(&settings.schedules[index])
            }
        }
    }
}

struct PrivacySettingsView: View {
    var session: LidSession

    var body: some View {
        Form {
            Section("Local processing") {
                Text("Lid reads the lid-angle sensor on this Mac and runs actions locally. There is no account, no network client, and no analytics.")
            }
            Section("Permissions") {
                LabeledContent("Accessibility") {
                    Text(session.accessibilityStatus == .granted ? "Granted" : "Not granted")
                }
                Text("Needed only to send the standard lock shortcut when lock is enabled.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Request Accessibility") {
                    Task { await session.requestLockPermission() }
                }
                Button("Open System Settings") {
                    if let url = URL(string: "x-apple.systemsettings:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }
                Text("Music and Spotify may ask for Automation access after you enable media pause.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section {
                Button("Open diagnostics") { session.openDiagnostics() }
            }
        }
        .formStyle(.grouped)
    }
}
