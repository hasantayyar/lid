public protocol Sleeper: Sendable {
    func sleep(for duration: Duration) async throws
}

public struct TaskSleeper: Sleeper {
    public init() {}

    public func sleep(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }
}

public struct ImmediateSleeper: Sleeper {
    public init() {}

    public func sleep(for duration: Duration) async throws {
        _ = duration
        try Task.checkCancellation()
    }
}
