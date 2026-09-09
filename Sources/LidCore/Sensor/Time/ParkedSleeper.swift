public struct ParkedSleeper: Sleeper {
    public init() {}

    public func sleep(for duration: Duration) async throws {
        _ = duration
        try await Task.sleep(for: .seconds(3_600))
    }
}