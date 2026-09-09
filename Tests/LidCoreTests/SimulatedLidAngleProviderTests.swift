import XCTest
@testable import LidCore

final class SimulatedLidAngleProviderTests: XCTestCase {
    func testPlaysScriptedAngles() async throws {
        let provider = SimulatedLidAngleProvider(
            configuration: SimulatedLidConfiguration(
                script: [.angle(90), .angle(74), .angle(20)],
                continueAfterScript: false
            ),
            clock: ControllableClock(),
            sleeper: ImmediateSleeper()
        )
        try await provider.start()
        let samples = await collect(provider.readings, count: 3)
        await provider.stop()
        XCTAssertEqual(samples.map(\.degrees), [90, 74, 20])
        XCTAssertTrue(samples.allSatisfy { $0.quality == .valid })
    }

    func testInjectsInvalidReading() async throws {
        let provider = SimulatedLidAngleProvider(
            configuration: SimulatedLidConfiguration(script: [.angle(80), .invalid, .angle(81)]),
            sleeper: ImmediateSleeper()
        )
        try await provider.start()
        let samples = await collect(provider.readings, count: 3)
        await provider.stop()
        XCTAssertEqual(samples.map(\.quality), [.valid, .invalid, .valid])
    }

    func testDisconnectStopsAnglesUntilReconnect() async throws {
        let provider = SimulatedLidAngleProvider(
            configuration: SimulatedLidConfiguration(
                script: [.angle(70), .disconnect, .angle(10), .reconnect, .angle(65)]
            ),
            sleeper: ImmediateSleeper()
        )
        try await provider.start()
        let samples = await collect(provider.readings, count: 2)
        let diagnostics = await provider.diagnostics()
        await provider.stop()
        XCTAssertEqual(samples.map(\.degrees), [70, 65])
        XCTAssertEqual(diagnostics.state, .available)
    }

    func testJitterUsesInjectedGenerator() async throws {
        let provider = SimulatedLidAngleProvider(
            configuration: SimulatedLidConfiguration(jitterDegrees: 2),
            sleeper: ImmediateSleeper(),
            randomNumberGenerator: FixedRandomNumberGenerator(value: 1.5)
        )
        try await provider.start()
        let samples = await collect(provider.readings, count: 1)
        await provider.stop()
        XCTAssertEqual(samples.first?.degrees, 91.5)
    }

    func testUnavailableWhenInitiallyDisconnected() async throws {
        let provider = SimulatedLidAngleProvider(
            configuration: SimulatedLidConfiguration(initiallyConnected: false),
            sleeper: ImmediateSleeper()
        )
        try await provider.start()
        let diagnostics = await provider.diagnostics()
        await provider.stop()
        XCTAssertEqual(diagnostics.state, .unavailable)
        XCTAssertNil(diagnostics.lastNormalizedDegrees)
        XCTAssertEqual(diagnostics.lastErrorCode, SensorError.unavailable.sanitizedCode)
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
