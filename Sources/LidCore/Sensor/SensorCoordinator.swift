public actor SensorCoordinator {
    public nonisolated let readings: AsyncStream<LidAngleSample>

    private let continuation: AsyncStream<LidAngleSample>.Continuation
    private let provider: any LidAngleProviding
    private let clock: any NanosecondClock
    private let sleeper: any Sleeper
    private let timing: SensorTiming
    private var sanitizer: SampleSanitizer
    private var consumeTask: Task<Void, Never>?
    private var watchdogTask: Task<Void, Never>?
    private var started = false
    private var lastForwarded: LidAngleSample?
    private var lastValidAt: UInt64?
    private var lastErrorCode: String?
    private var stale = false

    public init(
        provider: any LidAngleProviding,
        timing: SensorTiming = .production,
        clock: any NanosecondClock = SystemNanosecondClock(),
        sleeper: any Sleeper = TaskSleeper()
    ) {
        let (stream, continuation) = AsyncStream.makeStream(
            of: LidAngleSample.self,
            bufferingPolicy: .bufferingNewest(8)
        )
        readings = stream
        self.continuation = continuation
        self.provider = provider
        self.timing = timing
        self.clock = clock
        self.sleeper = sleeper
        sanitizer = SampleSanitizer(maxStepDegrees: timing.implausibleJumpDegrees)
    }

    deinit {
        continuation.finish()
    }

    public func start() async throws {
        guard !started else {
            throw SensorError.alreadyStarted
        }
        started = true
        stale = false
        lastErrorCode = nil
        try await provider.start()
        consumeTask = Task { [weak self] in
            await self?.consume()
        }
        watchdogTask = Task { [weak self] in
            await self?.watch()
        }
        LidLog.lifecycle.info("sensor coordinator start")
    }

    public func stop() async {
        started = false
        consumeTask?.cancel()
        consumeTask = nil
        watchdogTask?.cancel()
        watchdogTask = nil
        await provider.stop()
        LidLog.lifecycle.info("sensor coordinator stop")
    }

    public func diagnostics() async -> SensorDiagnostics {
        evaluateStale()
        var snapshot = await provider.diagnostics()
        if let lastForwarded {
            snapshot.lastNormalizedDegrees = lastForwarded.degrees
            snapshot.lastQuality = lastForwarded.quality
            if lastForwarded.quality == .valid {
                snapshot.lastSuccessfulReadingNanoseconds = lastForwarded.collectedAtNanoseconds
            }
        }
        if stale {
            snapshot.lastErrorCode = "stale_reading"
        } else if let lastErrorCode {
            snapshot.lastErrorCode = lastErrorCode
        }
        return snapshot
    }

    public func evaluateStaleForTesting() {
        evaluateStale()
    }

    private func consume() async {
        for await sample in provider.readings {
            if Task.isCancelled || !started {
                return
            }
            let sanitized = sanitizer.process(sample)
            lastForwarded = sanitized
            if sanitized.quality == .valid {
                lastValidAt = sanitized.collectedAtNanoseconds
                lastErrorCode = nil
                stale = false
            } else if sanitized.quality == .invalid {
                lastErrorCode = "invalid_sample"
            } else if sanitized.quality == .suspect {
                lastErrorCode = "suspect_sample"
            }
            continuation.yield(sanitized)
        }
    }

    private func watch() async {
        while started && !Task.isCancelled {
            evaluateStale()
            do {
                try await sleeper.sleep(for: timing.pollInterval)
            } catch {
                return
            }
        }
    }

    private func evaluateStale() {
        guard started else { return }
        guard let lastValidAt else { return }
        let elapsed = clock.nowNanoseconds() &- lastValidAt
        if elapsed > timing.invalidReadingTimeout.nanosecondCount {
            stale = true
            lastErrorCode = "stale_reading"
        }
    }
}
