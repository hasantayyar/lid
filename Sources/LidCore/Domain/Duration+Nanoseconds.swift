extension Duration {
    public var nanosecondCount: UInt64 {
        let parts = components
        let seconds = UInt64(max(parts.seconds, 0)) * 1_000_000_000
        let nanos = UInt64(max(parts.attoseconds, 0) / 1_000_000_000)
        return seconds &+ nanos
    }
}
