import Foundation

public protocol NanosecondClock: Sendable {
    func nowNanoseconds() -> UInt64
}

public struct SystemNanosecondClock: NanosecondClock {
    public init() {}

    public func nowNanoseconds() -> UInt64 {
        DispatchTime.now().uptimeNanoseconds
    }
}

public final class ControllableClock: NanosecondClock, @unchecked Sendable {
    private let lock = NSLock()
    private var value: UInt64

    public init(start: UInt64 = 0) {
        value = start
    }

    public func nowNanoseconds() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    public func advance(by nanoseconds: UInt64) {
        lock.lock()
        value &+= nanoseconds
        lock.unlock()
    }
}
