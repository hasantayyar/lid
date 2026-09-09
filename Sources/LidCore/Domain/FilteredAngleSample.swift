public struct FilteredAngleSample: Sendable, Hashable, Equatable {
    public var degrees: Double
    public var collectedAtNanoseconds: UInt64
    public var sampleCount: Int
    public var isStable: Bool

    public init(degrees: Double, collectedAtNanoseconds: UInt64, sampleCount: Int, isStable: Bool) {
        self.degrees = degrees
        self.collectedAtNanoseconds = collectedAtNanoseconds
        self.sampleCount = sampleCount
        self.isStable = isStable
    }
}
