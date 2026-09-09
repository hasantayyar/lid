import XCTest
@testable import LidCore

final class HardwareProbeTests: XCTestCase {
    func testHardwareProbeIsOptIn() async throws {
        guard ProcessInfo.processInfo.environment["LID_HARDWARE_TEST"] == "1" else {
            throw XCTSkip("Hardware tests are opt-in. Set LID_HARDWARE_TEST=1 on a machine with a lid sensor.")
        }

        let candidates = IOKitLidAngleProbe.listCandidates()
        XCTAssertFalse(candidates.isEmpty, "expected at least one HID candidate on this machine")
        XCTAssertTrue(candidates.contains(where: \.validated), "expected a validated lid-angle report")

        let provider = IOKitLidAngleProvider(
            timing: SensorTiming(pollInterval: .milliseconds(50))
        )
        let coordinator = SensorCoordinator(provider: provider)
        try await coordinator.start()
        let sample = await firstSample(coordinator.readings)
        let diagnostics = await coordinator.diagnostics()
        await coordinator.stop()

        XCTAssertNotNil(sample)
        XCTAssertEqual(diagnostics.state, .available)
        XCTAssertNotNil(diagnostics.lastNormalizedDegrees)
        XCTAssertNotEqual(diagnostics.state, .unavailable)
    }
}

private func firstSample(_ stream: AsyncStream<LidAngleSample>) async -> LidAngleSample? {
    let task = Task { () -> LidAngleSample? in
        for await sample in stream {
            return sample
        }
        return nil
    }
    try? await Task.sleep(for: .seconds(2))
    task.cancel()
    return await task.value
}
