import Foundation

public struct AutomationSnapshot: Sendable, Equatable {
    public var filtered: FilteredAngleSample?
    public var decision: ThresholdDecision
    public var snooze: SnoozeState
    public var displayState: AutomationDisplayState
}

public actor AutomationEngine {
    private var filter: AngleFilter
    private var machine: ThresholdStateMachine
    private var machineState = ThresholdMachineState()
    private let resolver = RuleResolver()
    private var snooze = SnoozeState.inactive
    private var lastQuality: SampleQuality = .invalid

    public init(timing: SensorTiming = .production) {
        filter = AngleFilter(windowSize: timing.medianWindow, smoothingAlpha: timing.smoothingAlpha)
        machine = ThresholdStateMachine(
            hysteresisDegrees: timing.hysteresisDegrees,
            cooldown: timing.cooldown
        )
    }

    public func setSnooze(_ option: SnoozeOption?, now: Date) {
        if let option {
            snooze = .starting(option, now: now)
        } else {
            snooze = .inactive
        }
    }

    public func currentSnooze() -> SnoozeState {
        snooze
    }

    public func resetFilter() {
        filter.reset()
        machineState = ThresholdMachineState()
    }

    public func evaluate(
        sample: LidAngleSample?,
        isStale: Bool,
        settings: AppSettings,
        foregroundBundleID: String?,
        nowMonotonic: UInt64,
        nowWall: Date,
        calendar: Calendar
    ) -> AutomationSnapshot {
        if let ends = snooze.endsAt, nowWall >= ends, !snooze.isManual {
            snooze = .inactive
        }

        let resolution = resolver.resolve(
            settings: settings,
            snooze: snooze,
            now: nowWall,
            calendar: calendar,
            foregroundBundleID: foregroundBundleID
        )

        var filtered: FilteredAngleSample?
        var quality = SampleQuality.invalid
        if let sample {
            quality = sample.quality
            lastQuality = quality
            filtered = filter.process(sample)
        }

        let decision = machine.evaluate(
            filtered: filtered,
            sampleQuality: quality,
            isStale: isStale,
            settings: settings,
            resolution: resolution,
            now: nowMonotonic,
            state: machineState
        )
        machineState = decision.state

        let display: AutomationDisplayState
        switch resolution {
        case .inactiveGlobal: display = .off
        case .snoozed: display = .snoozed
        case .active, .excludedApplication, .outsideSchedule: display = settings.automationEnabled ? .on : .off
        }

        return AutomationSnapshot(
            filtered: filtered,
            decision: decision,
            snooze: snooze,
            displayState: display
        )
    }
}
