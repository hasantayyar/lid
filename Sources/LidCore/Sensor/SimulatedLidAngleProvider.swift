public enum SimulatedLidEvent: Sendable, Equatable, Codable {
    case angle(Double)
    case invalid
    case suspect(Double)
    case disconnect
    case reconnect
    case wait(nanoseconds: UInt64)
}

public struct SimulatedLidConfiguration: Sendable, Equatable {
    public var adapterName: String
    public var pollInterval: Duration
    public var script: [SimulatedLidEvent]
    public var loopScript: Bool
    public var continueAfterScript: Bool
    public var jitterDegrees: Double
    public var initiallyConnected: Bool

    public init(
        adapterName: String = "SimulatedLidAngleProvider",
        pollInterval: Duration = .milliseconds(100),
        script: [SimulatedLidEvent] = [],
        loopScript: Bool = false,
        continueAfterScript: Bool = false,
        jitterDegrees: Double = 0,
        initiallyConnected: Bool = true
    ) {
        self.adapterName = adapterName
        self.pollInterval = pollInterval
        self.script = script
        self.loopScript = loopScript
        self.continueAfterScript = continueAfterScript
        self.jitterDegrees = jitterDegrees
        self.initiallyConnected = initiallyConnected
    }
}

public actor SimulatedLidAngleProvider: LidAngleProviding {
    public nonisolated let readings: AsyncStream<LidAngleSample>

    private let continuation: AsyncStream<LidAngleSample>.Continuation
    private let clock: any NanosecondClock
    private let sleeper: any Sleeper
    private let randomNumberGenerator: any RandomNumberGenerating
    private var configuration: SimulatedLidConfiguration
    private var host: HostIdentity
    private var state: SensorState = .stopped
    private var connected: Bool
    private var liveDegrees: Double = 90
    private var started = false
    private var runTask: Task<Void, Never>?
    private var lastSample: LidAngleSample?
    private var lastErrorCode: String?

    public init(
        configuration: SimulatedLidConfiguration = SimulatedLidConfiguration(),
        clock: any NanosecondClock = SystemNanosecondClock(),
        sleeper: any Sleeper = TaskSleeper(),
        randomNumberGenerator: any RandomNumberGenerating = SystemRandomNumberGeneratorBox(),
        host: HostIdentity = .current()
    ) {
        let (stream, continuation) = AsyncStream.makeStream(
            of: LidAngleSample.self,
            bufferingPolicy: .bufferingNewest(8)
        )
        readings = stream
        self.continuation = continuation
        self.clock = clock
        self.sleeper = sleeper
        self.randomNumberGenerator = randomNumberGenerator
        self.configuration = configuration
        self.host = host
        connected = configuration.initiallyConnected
    }

    deinit {
        continuation.finish()
        runTask?.cancel()
    }

    public func start() async throws {
        guard !started else {
            throw SensorError.alreadyStarted
        }
        started = true
        connected = configuration.initiallyConnected
        state = connected ? .available : .unavailable
        lastErrorCode = connected ? nil : SensorError.unavailable.sanitizedCode
        LidLog.lifecycle.info("simulated provider start connected=\(self.connected, privacy: .public)")
        runTask = Task { [weak self] in
            await self?.run()
        }
    }

    public func stop() async {
        started = false
        runTask?.cancel()
        runTask = nil
        state = .stopped
        LidLog.lifecycle.info("simulated provider stop")
    }

    public func diagnostics() async -> SensorDiagnostics {
        SensorDiagnostics(
            adapterName: configuration.adapterName,
            state: state,
            host: host,
            lastRawDegrees: lastSample?.degrees,
            lastNormalizedDegrees: lastSample?.degrees,
            lastQuality: lastSample?.quality,
            lastSuccessfulReadingNanoseconds: lastSample?.quality == .valid
                ? lastSample?.collectedAtNanoseconds
                : nil,
            lastErrorCode: lastErrorCode
        )
    }

    public func setAngle(_ degrees: Double) {
        liveDegrees = degrees
        if started, connected {
            emit(degrees: degrees, quality: .valid)
        }
    }

    public func injectInvalid() {
        if started {
            emit(degrees: liveDegrees, quality: .invalid)
            lastErrorCode = SensorError.invalidReport(code: "simulated").sanitizedCode
        }
    }

    public func disconnect() {
        connected = false
        state = started ? .unavailable : state
        lastErrorCode = SensorError.unavailable.sanitizedCode
        LidLog.sensor.info("simulated disconnect")
    }

    public func reconnect() {
        connected = true
        if started {
            state = .available
            lastErrorCode = nil
        }
        LidLog.sensor.info("simulated reconnect")
    }

    public func setJitterDegrees(_ jitter: Double) {
        configuration.jitterDegrees = jitter
    }

    private func run() async {
        if configuration.script.isEmpty {
            await runLive()
            return
        }
        await runScript()
        if configuration.continueAfterScript && started {
            await runLive()
        }
    }

    private func runScript() async {
        repeat {
            for event in configuration.script {
                if Task.isCancelled || !started {
                    return
                }
                await handle(event)
            }
        } while configuration.loopScript && started && !Task.isCancelled
    }

    private func runLive() async {
        while started && !Task.isCancelled {
            if connected {
                let jitter = configuration.jitterDegrees
                let offset = jitter > 0
                    ? randomNumberGenerator.nextDouble(in: -jitter...jitter)
                    : 0
                emit(degrees: liveDegrees + offset, quality: .valid)
            }
            do {
                try await sleeper.sleep(for: configuration.pollInterval)
            } catch {
                return
            }
        }
    }

    private func handle(_ event: SimulatedLidEvent) async {
        switch event {
        case .angle(let degrees):
            liveDegrees = degrees
            if connected {
                emit(degrees: degrees, quality: .valid)
            }
        case .invalid:
            emit(degrees: liveDegrees, quality: .invalid)
            lastErrorCode = SensorError.invalidReport(code: "simulated").sanitizedCode
        case .suspect(let degrees):
            liveDegrees = degrees
            if connected {
                emit(degrees: degrees, quality: .suspect)
            }
        case .disconnect:
            disconnect()
        case .reconnect:
            reconnect()
        case .wait(let nanoseconds):
            do {
                try await sleeper.sleep(for: .nanoseconds(nanoseconds))
            } catch {
                return
            }
        }
    }

    private func emit(degrees: Double, quality: SampleQuality) {
        let sample = LidAngleSample(
            degrees: degrees,
            collectedAtNanoseconds: clock.nowNanoseconds(),
            quality: quality
        )
        lastSample = sample
        if quality == .valid {
            lastErrorCode = nil
            state = .available
        }
        continuation.yield(sample)
    }
}
