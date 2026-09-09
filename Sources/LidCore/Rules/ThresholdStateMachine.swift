public struct ThresholdMachineState: Sendable, Equatable {
    public var previousAngle: Double?
    public var armed: [ActionID: Bool]
    public var lastFiredAt: [ActionID: UInt64]
    public var overlayActive: Bool

    public init(
        previousAngle: Double? = nil,
        armed: [ActionID: Bool] = Dictionary(uniqueKeysWithValues: ActionID.allCases.map { ($0, true) }),
        lastFiredAt: [ActionID: UInt64] = [:],
        overlayActive: Bool = false
    ) {
        self.previousAngle = previousAngle
        self.armed = armed
        self.lastFiredAt = lastFiredAt
        self.overlayActive = overlayActive
    }
}

public struct ThresholdDecision: Sendable, Equatable {
    public var state: ThresholdMachineState
    public var intents: [ActionIntent]
    public var resolution: RuleResolution
}

public struct ThresholdStateMachine: Sendable {
    public var hysteresisDegrees: Double
    public var cooldown: Duration

    public init(hysteresisDegrees: Double = 5, cooldown: Duration = .seconds(3)) {
        self.hysteresisDegrees = hysteresisDegrees
        self.cooldown = cooldown
    }

    public func evaluate(
        filtered: FilteredAngleSample?,
        sampleQuality: SampleQuality,
        isStale: Bool,
        settings: AppSettings,
        resolution: RuleResolution,
        now: UInt64,
        state: ThresholdMachineState
    ) -> ThresholdDecision {
        var next = state
        var intents: [ActionIntent] = []

        if !resolution.allowsActions {
            if resolution == .snoozed || resolution == .inactiveGlobal, next.overlayActive {
                intents.append(.reset(.privacyOverlay))
                next.overlayActive = false
            }
            if let filtered {
                next.previousAngle = filtered.degrees
                next = rearmIfNeeded(next, angle: filtered.degrees, settings: settings, intents: &intents)
            }
            return ThresholdDecision(state: next, intents: intents, resolution: resolution)
        }

        guard !isStale else {
            return ThresholdDecision(state: next, intents: [], resolution: resolution)
        }
        guard sampleQuality == .valid, let filtered, filtered.isStable else {
            return ThresholdDecision(state: next, intents: [], resolution: resolution)
        }

        next = rearmIfNeeded(next, angle: filtered.degrees, settings: settings, intents: &intents)

        if let previous = next.previousAngle {
            for action in ActionIntentOrdering.applyOrder {
                guard let threshold = settings.threshold(for: action) else { continue }
                let crossed = previous > threshold && filtered.degrees <= threshold
                guard crossed else { continue }
                guard next.armed[action, default: true] else { continue }
                if let last = next.lastFiredAt[action], now &- last < cooldown.nanosecondCount {
                    continue
                }
                intents.append(.apply(action))
                next.armed[action] = false
                next.lastFiredAt[action] = now
                if action == .privacyOverlay {
                    next.overlayActive = true
                }
                if action == .lock, next.overlayActive {
                    intents.append(.reset(.privacyOverlay))
                    next.overlayActive = false
                }
            }
        }

        next.previousAngle = filtered.degrees
        return ThresholdDecision(state: next, intents: intents, resolution: resolution)
    }

    private func rearmIfNeeded(
        _ state: ThresholdMachineState,
        angle: Double,
        settings: AppSettings,
        intents: inout [ActionIntent]
    ) -> ThresholdMachineState {
        var next = state
        for action in ActionID.allCases {
            guard let threshold = settings.threshold(for: action) else { continue }
            if angle > threshold + hysteresisDegrees {
                if next.armed[action] == false {
                    next.armed[action] = true
                    if action == .privacyOverlay, next.overlayActive {
                        intents.append(.reset(.privacyOverlay))
                        next.overlayActive = false
                    }
                } else {
                    next.armed[action] = true
                }
            }
        }
        return next
    }
}
