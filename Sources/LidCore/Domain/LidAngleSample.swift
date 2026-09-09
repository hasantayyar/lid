public struct LidAngleSample: Sendable, Hashable, Codable, Equatable {
    public var degrees: Double
    public var collectedAtNanoseconds: UInt64
    public var quality: SampleQuality

    public init(degrees: Double, collectedAtNanoseconds: UInt64, quality: SampleQuality) {
        self.degrees = degrees
        self.collectedAtNanoseconds = collectedAtNanoseconds
        self.quality = quality
    }

    public func replacingQuality(_ quality: SampleQuality) -> LidAngleSample {
        LidAngleSample(
            degrees: degrees,
            collectedAtNanoseconds: collectedAtNanoseconds,
            quality: quality
        )
    }
}
