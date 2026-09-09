import XCTest
@testable import LidCore

final class SettingsAndExecutorTests: XCTestCase {
    func testRejectsInvalidThresholds() {
        XCTAssertThrowsError(
            try AppSettings(privacy: ThresholdActionSettings(enabled: true, thresholdDegrees: 1))
        )
    }

    func testRejectsLockTooCloseToPrivacy() {
        XCTAssertThrowsError(
            try AppSettings(
                privacy: ThresholdActionSettings(enabled: true, thresholdDegrees: 30),
                lock: ThresholdActionSettings(enabled: true, thresholdDegrees: 25)
            )
        )
    }

    func testImportRejectsHugePayload() async throws {
        let store = SettingsStore(defaults: UserDefaults(suiteName: "lid.test.settings")!)
        let data = Data(repeating: 64, count: SettingsStore.maximumImportBytes + 1)
        do {
            try await store.importJSON(data)
            XCTFail("expected payloadTooLarge")
        } catch SettingsValidationError.payloadTooLarge {
            // expected
        }
    }

    func testImportRejectsUnknownSchema() throws {
        let json = Data("{\"schemaVersion\":99}".utf8)
        XCTAssertThrowsError(try SettingsMigrator.decode(json))
    }

    func testExecutorContinuesAfterMediaUnknown() async {
        let overlay = FakeOverlayController()
        let locker = FakeScreenLocker()
        let media = FakeMediaController(state: .unknown)
        let executor = ActionExecutor(overlay: overlay, locker: locker, media: media)
        let results = await executor.execute(
            [.apply(.privacyOverlay), .apply(.mediaPause), .apply(.lock)],
            context: ActionContext(settings: .default)
        )
        XCTAssertEqual(results[.apply(.privacyOverlay)], .succeeded)
        XCTAssertEqual(results[.apply(.mediaPause)], .skipped(.mediaStateUnknown))
        XCTAssertEqual(results[.apply(.lock)], .submittedUnverified)
        let locks = await locker.lockCount
        XCTAssertEqual(locks, 1)
    }

    func testLockDeniedDoesNotPretendSuccess() async {
        let locker = FakeScreenLocker()
        await locker.setDenied()
        let executor = ActionExecutor(
            overlay: FakeOverlayController(),
            locker: locker,
            media: FakeMediaController()
        )
        let results = await executor.execute(
            [.apply(.lock)],
            context: ActionContext(settings: .default)
        )
        XCTAssertEqual(results[.apply(.lock)], .denied(.accessibility))
    }

    func testSnoozeExpiresByWallClock() async {
        let clock = ControllableWallClock(date: Date(timeIntervalSince1970: 1_000))
        let engine = AutomationEngine(timing: SensorTiming(medianWindow: 1, cooldown: .seconds(0)))
        await engine.setSnooze(.minutes5, now: clock.now())
        clock.advance(by: 4 * 60)
        var snapshot = await engine.evaluate(
            sample: LidAngleSample(degrees: 90, collectedAtNanoseconds: 1, quality: .valid),
            isStale: false,
            settings: .default,
            foregroundBundleID: nil,
            nowMonotonic: 1,
            nowWall: clock.now(),
            calendar: Calendar(identifier: .gregorian)
        )
        XCTAssertEqual(snapshot.displayState, .snoozed)
        clock.advance(by: 2 * 60)
        snapshot = await engine.evaluate(
            sample: LidAngleSample(degrees: 90, collectedAtNanoseconds: 2, quality: .valid),
            isStale: false,
            settings: .default,
            foregroundBundleID: nil,
            nowMonotonic: 2,
            nowWall: clock.now(),
            calendar: Calendar(identifier: .gregorian)
        )
        XCTAssertEqual(snapshot.displayState, .on)
    }
}

extension FakeScreenLocker {
    func setDenied() {
        status = .denied
    }
}

