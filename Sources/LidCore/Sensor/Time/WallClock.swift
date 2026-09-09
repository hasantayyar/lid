import Foundation

public protocol WallClock: Sendable {
    func now() -> Date
}

public struct SystemWallClock: WallClock {
    public init() {}

    public func now() -> Date {
        Date()
    }
}

public final class ControllableWallClock: WallClock, @unchecked Sendable {
    private let lock = NSLock()
    private var date: Date

    public init(date: Date = Date(timeIntervalSince1970: 1_700_000_000)) {
        self.date = date
    }

    public func now() -> Date {
        lock.lock()
        defer { lock.unlock() }
        return date
    }

    public func set(_ date: Date) {
        lock.lock()
        self.date = date
        lock.unlock()
    }

    public func advance(by interval: TimeInterval) {
        lock.lock()
        date = date.addingTimeInterval(interval)
        lock.unlock()
    }
}
