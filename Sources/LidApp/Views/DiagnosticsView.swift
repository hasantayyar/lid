import AppKit
import LidCore
import SwiftUI

struct DiagnosticsView: View {
    @Bindable var session: LidSession

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Group {
                labeled("Hardware", session.host.modelIdentifier)
                labeled("macOS", session.host.macOSVersion)
                labeled("Adapter", session.sensorDiagnostics?.adapterName ?? "none")
                labeled("State", session.sensorStateText)
                labeled("Raw angle", session.rawAngle.map { String(format: "%.1f°", $0) } ?? "none")
                labeled("Filtered angle", session.filteredAngle.map { String(format: "%.1f°", $0) } ?? "none")
                labeled("Last error", session.lastErrorCode ?? "none")
                labeled("Effective rule", session.resolutionTitle)
            }
            .textSelection(.enabled)

            #if DEBUG
            Toggle("Use simulated sensor", isOn: Binding(
                get: { session.useSimulator },
                set: { value in
                    Task { await session.toggleSimulator(value) }
                }
            ))
            if session.useSimulator {
                Slider(value: $session.simulatedAngle, in: 0...135, step: 1) {
                    Text("Simulated lid")
                }
                .onChange(of: session.simulatedAngle) { _, value in
                    Task { await session.setSimulatedAngle(value) }
                }
            }
            #endif

            List(session.events) { event in
                VStack(alignment: .leading) {
                    Text(event.code)
                        .font(.body.monospaced())
                    if let bundle = event.bundleIdentifier {
                        Text(bundle)
                            .font(.footnote.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack {
                Button("Export sanitized diagnostics") {
                    Task {
                        if let url = await session.exportDiagnostics() {
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        }
                    }
                }
                Text("Fields: \(DiagnosticsStore.exportedFields.joined(separator: ", "))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(minWidth: 520, minHeight: 420)
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}
