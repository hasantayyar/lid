import XCTest
@testable import LidCore

final class SensorCoordinatorTests: XCTestCase {
    func testUnavailableProviderDoesNotInventAnAngle() async throws {
        let provider = SimulatedLidAngleProvider(
            configuration: SimulatedLidConfiguration(initiallyConnected: false),
            sleeper: ImmediateSleeper()
        )
        let coordinator = SensorCoordinator(provider: provider, sleeper: ParkedSleeper())
        try await coordinator.start()
        let diagnostics = await coordinator.diagnostics()
        await coordinator.stop()
        XCTAssertEqual(diagnostics.state, .unavailable)
        XCTAssertNil(diagnostics.lastNormalizedDegrees)
    }

    func testForwardsSanitizedSamples() async throws {
        let provider = SimulatedLidAngleProvider(
            configuration: SimulatedLidConfiguration(script: [.angle(100), .angle(20), .angle(18)]),
            sleeper: ImmediateSleeper()
        )
        let coordinator = SensorCoordinator(
            provider: provider,
            timing: SensorTiming(implausibleJumpDegrees: 40),
            sleeper: ParkedSleeper()
        )
        try await coordinator.start()
        let samples = await collect(coordinator.readings, count: 3)
        await coordinator.stop()
        XCTAssertEqual(samples.map(\.quality), [.valid, .suspect, .valid])
    }

    func testStaleTimeoutUsesInjectedClock() async throws {
        let clock = ControllableClock()
        let provider = SimulatedLidAngleProvider(
            configuration: SimulatedLidConfiguration(script: [.angle(77)]),
            clock: clock,
            sleeper: ImmediateSleeper()
        )
        let coordinator = SensorCoordinator(
            provider: provider,
            timing: SensorTiming(invalidReadingTimeout: .seconds(2)),
            clock: clock,
            sleeper: ParkedSleeper()
        )
        try await coordinator.start()
        _ = await collect(coordinator.readings, count: 1)
        clock.advance(by: 3_000_000_000)
        await coordinator.evaluateStaleForTesting()
        let diagnostics = await coordinator.diagnostics()
        await coordinator.stop()
        XCTAssertEqual(diagnostics.lastErrorCode, "stale_reading")
        XCTAssertEqual(diagnostics.lastNormalizedDegrees, 77)
    }

    func testStopCancelsWorkAndLeavesNoOrphanedTasks() async throws {
        let provider = SimulatedLidAngleProvider(
            configuration: SimulatedLidConfiguration(script: [.angle(50)], continueAfterScript: false),
            sleeper: ImmediateSleeper()
        )
        let coordinator = SensorCoordinator(provider: provider, sleeper: ParkedSleeper())
        try await coordinator.start()
        _ = await collect(coordinator.readings, count: 1)
        await coordinator.stop()
        let diagnostics = await coordinator.diagnostics()
        XCTAssertEqual(diagnostics.state, .stopped)
    }
}

private func collect(_ stream: AsyncStream<LidAngleSample>, count: Int) async -> [LidAngleSample] {
    var samples: [LidAngleSample] = []
    for await sample in stream {
        samples.append(sample)
        if samples.count == count {
            break
        }
    }
    return samples
}
