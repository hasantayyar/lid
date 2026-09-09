public struct SensorTiming: Sendable, Hashable, Equatable {
    public var pollInterval: Duration
    public var invalidReadingTimeout: Duration
    public var reconnectBackoff: [Duration]
    public var implausibleJumpDegrees: Double
    public var medianWindow: Int
    public var smoothingAlpha: Double
    public var hysteresisDegrees: Double
    public var cooldown: Duration

    public init(
        pollInterval: Duration = .milliseconds(100),
        invalidReadingTimeout: Duration = .seconds(2),
        reconnectBackoff: [Duration] = [
            .seconds(1),
            .seconds(2),
            .seconds(4),
            .seconds(8),
            .seconds(15),
        ],
        implausibleJumpDegrees: Double = 40,
        medianWindow: Int = 5,
        smoothingAlpha: Double = 0.35,
        hysteresisDegrees: Double = 5,
        cooldown: Duration = .seconds(3)
    ) {
        self.pollInterval = pollInterval
        self.invalidReadingTimeout = invalidReadingTimeout
        self.reconnectBackoff = reconnectBackoff.isEmpty ? [.seconds(15)] : reconnectBackoff
        self.implausibleJumpDegrees = implausibleJumpDegrees
        self.medianWindow = max(medianWindow, 1)
        self.smoothingAlpha = smoothingAlpha
        self.hysteresisDegrees = hysteresisDegrees
        self.cooldown = cooldown
    }

    public static let production = SensorTiming()

    public func backoffDelay(forAttempt attempt: Int) -> Duration {
        let index = min(max(attempt, 0), reconnectBackoff.count - 1)
        return reconnectBackoff[index]
    }
}
