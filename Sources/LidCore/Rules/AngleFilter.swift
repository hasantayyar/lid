public struct AngleFilter: Sendable, Equatable {
    public var windowSize: Int
    public var smoothingAlpha: Double
    private var window: [Double] = []
    private var smoothed: Double?

    public init(windowSize: Int = 5, smoothingAlpha: Double = 0.35) {
        self.windowSize = max(windowSize, 1)
        self.smoothingAlpha = smoothingAlpha
    }

    public mutating func process(_ sample: LidAngleSample) -> FilteredAngleSample? {
        guard sample.quality == .valid else {
            return nil
        }
        window.append(sample.degrees)
        if window.count > windowSize {
            window.removeFirst()
        }
        let median = Self.median(window)
        let filtered: Double
        if let smoothed {
            filtered = smoothed + smoothingAlpha * (median - smoothed)
        } else {
            filtered = median
        }
        self.smoothed = filtered
        return FilteredAngleSample(
            degrees: filtered,
            collectedAtNanoseconds: sample.collectedAtNanoseconds,
            sampleCount: window.count,
            isStable: window.count >= windowSize
        )
    }

    public mutating func reset() {
        window = []
        smoothed = nil
    }

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }
}
