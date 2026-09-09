/// Marks implausible angle jumps suspect until a later sample confirms them.
public struct SampleSanitizer: Sendable, Equatable {
    public var maxStepDegrees: Double
    private var lastAcceptedDegrees: Double?
    private var pendingDegrees: Double?

    public init(maxStepDegrees: Double = 40) {
        self.maxStepDegrees = maxStepDegrees
    }

    public mutating func process(_ sample: LidAngleSample) -> LidAngleSample {
        guard sample.quality != .invalid else {
            return sample
        }

        guard let accepted = lastAcceptedDegrees else {
            lastAcceptedDegrees = sample.degrees
            pendingDegrees = nil
            return sample
        }

        if abs(sample.degrees - accepted) <= maxStepDegrees {
            lastAcceptedDegrees = sample.degrees
            pendingDegrees = nil
            return sample
        }

        if let pending = pendingDegrees, abs(sample.degrees - pending) <= maxStepDegrees {
            lastAcceptedDegrees = sample.degrees
            pendingDegrees = nil
            return sample.replacingQuality(.valid)
        }

        pendingDegrees = sample.degrees
        return sample.replacingQuality(.suspect)
    }
}
