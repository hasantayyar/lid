import XCTest
@testable import LidCore

final class ThresholdStateMachineTests: XCTestCase {
    private let machine = ThresholdStateMachine(hysteresisDegrees: 5, cooldown: .seconds(3))
    private let settings = AppSettings.default
    private let active = RuleResolution.active(reason: "Default rule")

    func testExactDownwardCrossingFiresOnce() {
        var state = ThresholdMachineState(previousAngle: 61)
        let first = decide(60, at: 1, state: state)
        XCTAssertEqual(applyIDs(first), [.privacyOverlay, .mediaPause])
        state = first.state
        let second = decide(59, at: 2, state: state)
        XCTAssertTrue(applyIDs(second).isEmpty)
    }

    func testNoTriggerWhileRemainingBelow() {
        var state = ThresholdMachineState(previousAngle: 60)
        state.armed[.privacyOverlay] = false
        state.armed[.mediaPause] = false
        let decision = decide(40, at: 1, state: state)
        XCTAssertTrue(applyIDs(decision).isEmpty)
    }

    func testRearmOnlyAfterHysteresis() {
        var state = ThresholdMachineState(previousAngle: 50)
        state.armed[.privacyOverlay] = false
        state.armed[.mediaPause] = false
        let below = decide(64, at: 1, state: state)
        XCTAssertTrue(applyIDs(below).isEmpty)
        XCTAssertEqual(below.state.armed[.privacyOverlay], false)
        let above = decide(66, at: 2, state: below.state)
        XCTAssertEqual(above.state.armed[.privacyOverlay], true)
        let fire = decide(60, at: 3_000_000_001, state: above.state)
        XCTAssertTrue(applyIDs(fire).contains(.privacyOverlay))
    }

    func testMultipleThresholdsInOneSampleUseDeterministicOrder() {
        let decision = decide(15, at: 1, state: ThresholdMachineState(previousAngle: 70))
        XCTAssertEqual(applyIDs(decision), [.privacyOverlay, .mediaPause, .lock])
        XCTAssertTrue(decision.intents.contains(.reset(.privacyOverlay)))
    }

    func testDedupOncePerDownwardCycle() {
        var state = ThresholdMachineState(previousAngle: 70)
        let first = decide(50, at: 1, state: state)
        state = first.state
        let second = decide(49, at: 4_000_000_000, state: state)
        XCTAssertTrue(applyIDs(second).isEmpty)
    }

    func testCooldownBlocksImmediateRetriggerAfterRearm() {
        var state = ThresholdMachineState(previousAngle: 70)
        let first = decide(50, at: 1_000, state: state)
        state = first.state
        let rearmed = decide(70, at: 2_000, state: state)
        let again = decide(50, at: 3_000, state: rearmed.state)
        XCTAssertTrue(applyIDs(again).isEmpty)
    }

    func testStaleAndInvalidAndSuspectDoNotFire() {
        let stale = machine.evaluate(
            filtered: FilteredAngleSample(degrees: 20, collectedAtNanoseconds: 1, sampleCount: 5, isStable: true),
            sampleQuality: .valid,
            isStale: true,
            settings: settings,
            resolution: active,
            now: 1,
            state: ThresholdMachineState(previousAngle: 80)
        )
        XCTAssertTrue(stale.intents.isEmpty)

        let invalid = machine.evaluate(
            filtered: FilteredAngleSample(degrees: 20, collectedAtNanoseconds: 1, sampleCount: 5, isStable: true),
            sampleQuality: .invalid,
            isStale: false,
            settings: settings,
            resolution: active,
            now: 1,
            state: ThresholdMachineState(previousAngle: 80)
        )
        XCTAssertTrue(invalid.intents.isEmpty)
    }

    func testSnoozeRemovesOverlayAndBlocksNewActions() {
        var state = ThresholdMachineState(previousAngle: 40, overlayActive: true)
        state.armed[.privacyOverlay] = false
        let decision = machine.evaluate(
            filtered: FilteredAngleSample(degrees: 15, collectedAtNanoseconds: 1, sampleCount: 5, isStable: true),
            sampleQuality: .valid,
            isStale: false,
            settings: settings,
            resolution: .snoozed,
            now: 1,
            state: state
        )
        XCTAssertEqual(decision.intents, [.reset(.privacyOverlay)])
        XCTAssertFalse(applyIDs(decision).contains(.lock))
    }

    func testUnstableFilterDoesNotFire() {
        let decision = machine.evaluate(
            filtered: FilteredAngleSample(degrees: 20, collectedAtNanoseconds: 1, sampleCount: 2, isStable: false),
            sampleQuality: .valid,
            isStale: false,
            settings: settings,
            resolution: active,
            now: 1,
            state: ThresholdMachineState(previousAngle: 80)
        )
        XCTAssertTrue(decision.intents.isEmpty)
    }

    private func decide(_ angle: Double, at now: UInt64, state: ThresholdMachineState) -> ThresholdDecision {
        machine.evaluate(
            filtered: FilteredAngleSample(degrees: angle, collectedAtNanoseconds: now, sampleCount: 5, isStable: true),
            sampleQuality: .valid,
            isStale: false,
            settings: settings,
            resolution: active,
            now: now,
            state: state
        )
    }

    private func applyIDs(_ decision: ThresholdDecision) -> [ActionID] {
        decision.intents.compactMap { intent in
            if case .apply(let id) = intent { return id }
            return nil
        }
    }
}
