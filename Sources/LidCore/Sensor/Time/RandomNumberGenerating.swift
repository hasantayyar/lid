public protocol RandomNumberGenerating: Sendable {
    func nextDouble(in range: ClosedRange<Double>) -> Double
}

public struct SystemRandomNumberGeneratorBox: RandomNumberGenerating {
    public init() {}

    public func nextDouble(in range: ClosedRange<Double>) -> Double {
        Double.random(in: range)
    }
}

public struct FixedRandomNumberGenerator: RandomNumberGenerating {
    private let value: Double

    public init(value: Double) {
        self.value = value
    }

    public func nextDouble(in range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
