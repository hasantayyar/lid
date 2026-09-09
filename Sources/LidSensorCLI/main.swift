import Foundation
import LidCore

@main
struct LidSensorCLI {
    static func main() async {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if arguments.contains("--help") || arguments.contains("-h") {
            print(helpText)
            return
        }

        if arguments.contains("--list") {
            listCandidates()
            return
        }

        let simulate = arguments.contains("--simulate")
        let once = arguments.contains("--once")
        let duration = durationSeconds(from: arguments) ?? (once ? 0.3 : 3)

        let provider: any LidAngleProviding
        if simulate {
            provider = SimulatedLidAngleProvider(
                configuration: SimulatedLidConfiguration(
                    script: demoScript,
                    continueAfterScript: true
                )
            )
        } else {
            provider = IOKitLidAngleProvider()
        }

        let host = HostIdentity.current()
        print("Lid sensor diagnostic")
        print("Hardware: \(host.modelIdentifier)")
        print("macOS: \(host.macOSVersion) (\(host.operatingSystemVersionString))")
        print("Architecture: \(host.architecture)")
        print("Adapter: \(simulate ? "SimulatedLidAngleProvider" : "IOKitLidAngleProvider")")

        let coordinator = SensorCoordinator(provider: provider)
        let collector = Task {
            var printedAngle = false
            for await sample in coordinator.readings {
                let diagnostics = await coordinator.diagnostics()
                printSample(sample, diagnostics: diagnostics)
                printedAngle = printedAngle || sample.quality != .invalid
                if once {
                    break
                }
            }
            return printedAngle
        }

        do {
            try await coordinator.start()
        } catch {
            collector.cancel()
            FileHandle.standardError.write(Data("start failed: \(error)\n".utf8))
            exit(1)
        }

        let started = await coordinator.diagnostics()
        print("State: \(started.state.rawValue)")
        if let vendor = started.vendorID, let product = started.productID {
            print(String(format: "Match: vendor=0x%04x product=0x%04x", vendor, product))
        }
        if let page = started.usagePage, let usage = started.usage {
            print(String(format: "Usage: page=0x%04x usage=0x%04x", page, usage))
        }

        try? await Task.sleep(for: .seconds(duration))
        collector.cancel()
        let printedAngle = await collector.value

        let diagnostics = await coordinator.diagnostics()
        if diagnostics.state == .unavailable || diagnostics.state == .stopped {
            print("Sensor unavailable")
            if let code = diagnostics.lastErrorCode {
                print("Error: \(code)")
            }
        } else if diagnostics.lastErrorCode == "stale_reading" {
            print("Sensor stale")
        } else if !printedAngle, diagnostics.lastNormalizedDegrees == nil {
            print("Sensor \(diagnostics.state.rawValue)")
        }

        print("Exported diagnostic fields: \(diagnostics.exportedFields.joined(separator: ", "))")
        await coordinator.stop()
    }

    private static func printSample(_ sample: LidAngleSample, diagnostics: SensorDiagnostics) {
        switch diagnostics.state {
        case .unavailable, .stopped:
            return
        case .available, .reconnecting, .permissionBlocked:
            if sample.quality == .invalid {
                print("Reading: invalid (\(diagnostics.lastErrorCode ?? "invalid_sample"))")
            } else {
                print(String(format: "Angle: %.1f° quality=%@", sample.degrees, sample.quality.rawValue))
            }
        }
    }

    private static func listCandidates() {
        let host = HostIdentity.current()
        print("Lid sensor candidates")
        print("Hardware: \(host.modelIdentifier)")
        print("macOS: \(host.macOSVersion)")
        let candidates = IOKitLidAngleProbe.listCandidates()
        if candidates.isEmpty {
            print("Sensor unavailable")
            return
        }
        for candidate in candidates {
            print(format(candidate))
        }
    }

    private static func format(_ candidate: HIDDeviceCandidate) -> String {
        let vendor = candidate.vendorID.map { String(format: "0x%04x", $0) } ?? "none"
        let product = candidate.productID.map { String(format: "0x%04x", $0) } ?? "none"
        let page = candidate.usagePage.map { String(format: "0x%04x", $0) } ?? "none"
        let usage = candidate.usage.map { String(format: "0x%04x", $0) } ?? "none"
        let builtIn = candidate.builtIn.map { $0 ? "yes" : "no" } ?? "unknown"
        return "vendor=\(vendor) product=\(product) usagePage=\(page) usage=\(usage) builtIn=\(builtIn) validated=\(candidate.validated)"
    }

    private static func durationSeconds(from arguments: [String]) -> TimeInterval? {
        guard let index = arguments.firstIndex(of: "--duration"), arguments.indices.contains(index + 1) else {
            return nil
        }
        return TimeInterval(arguments[index + 1])
    }

    private static let demoScript: [SimulatedLidEvent] = [
        .angle(90),
        .angle(74),
        .angle(61),
        .angle(59),
        .angle(21),
        .angle(19),
        .invalid,
        .angle(80),
        .disconnect,
        .reconnect,
        .angle(85),
    ]

    private static let helpText = """
    lid-sensor — local lid-angle diagnostic

    Usage:
      lid-sensor [--once] [--duration seconds]
      lid-sensor --list
      lid-sensor --simulate [--duration seconds]
      lid-sensor --help

    Prints sanitized hardware and adapter diagnostics. Never prints raw HID payloads.
    Missing hardware is reported as Sensor unavailable.
    """
}
