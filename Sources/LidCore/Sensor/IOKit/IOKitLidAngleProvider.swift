#if os(macOS)
import Foundation
@preconcurrency import IOKit.hid

/// Undocumented HID matching. Keep every constant and unsafe HID call here.
enum LidHIDMatching {
    static let appleVendorID = 0x05AC
    static let sensorHubProductID = 0x8104
    static let sensorUsagePage = 0x0020
    static let orientationUsage = 0x008A
    static let featureReportID: CFIndex = 1
    static let reportBufferLength = 8
}

private struct IOKitProviderState {
    var manager: IOHIDManager?
    var device: IOHIDDevice?
    var runLoop: CFRunLoop?
    var runLoopThread: Thread?
    var started = false
    var hadValidatedDevice = false
    var state: SensorState = .stopped
    var lastSample: LidAngleSample?
    var lastRawDegrees: Double?
    var lastErrorCode: String?
    var lastVendorID: UInt32?
    var lastProductID: UInt32?
    var lastUsagePage: UInt32?
    var lastUsage: UInt32?
    var reconnectAttempt = 0
    var consecutiveInvalidReads = 0
}

public final class IOKitLidAngleProvider: LidAngleProviding, @unchecked Sendable {
    public nonisolated let readings: AsyncStream<LidAngleSample>

    private let continuation: AsyncStream<LidAngleSample>.Continuation
    private let clock: any NanosecondClock
    private let sleeper: any Sleeper
    private let timing: SensorTiming
    private let host: HostIdentity
    private let store = LockedValue(IOKitProviderState())
    private let runLoopStopped = DispatchSemaphore(value: 0)
    private var pollTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?

    public init(
        timing: SensorTiming = .production,
        clock: any NanosecondClock = SystemNanosecondClock(),
        sleeper: any Sleeper = TaskSleeper(),
        host: HostIdentity = .current()
    ) {
        let (stream, continuation) = AsyncStream.makeStream(
            of: LidAngleSample.self,
            bufferingPolicy: .bufferingNewest(8)
        )
        readings = stream
        self.continuation = continuation
        self.timing = timing
        self.clock = clock
        self.sleeper = sleeper
        self.host = host
    }

    deinit {
        tearDownHID()
        continuation.finish()
    }

    public func start() async throws {
        let alreadyStarted = store.withLock { state in
            if state.started {
                return true
            }
            state.started = true
            return false
        }
        if alreadyStarted {
            throw SensorError.alreadyStarted
        }

        do {
            try beginHID()
        } catch {
            store.withLock { $0.started = false }
            throw error
        }

        pollTask = Task { [weak self] in
            await self?.pollLoop()
        }
        LidLog.lifecycle.info("iokit provider start")
    }

    public func stop() async {
        store.withLock { $0.started = false }
        pollTask?.cancel()
        pollTask = nil
        reconnectTask?.cancel()
        reconnectTask = nil
        tearDownHID()
        store.withLock { $0.state = .stopped }
        LidLog.lifecycle.info("iokit provider stop")
    }

    public func diagnostics() async -> SensorDiagnostics {
        store.withLock { state in
            SensorDiagnostics(
                adapterName: "IOKitLidAngleProvider",
                state: state.state,
                host: host,
                vendorID: state.lastVendorID,
                productID: state.lastProductID,
                usagePage: state.lastUsagePage,
                usage: state.lastUsage,
                lastRawDegrees: state.lastRawDegrees,
                lastNormalizedDegrees: state.lastSample?.degrees,
                lastQuality: state.lastSample?.quality,
                lastSuccessfulReadingNanoseconds: state.lastSample?.quality == .valid
                    ? state.lastSample?.collectedAtNanoseconds
                    : nil,
                lastErrorCode: state.lastErrorCode,
                reconnectAttempt: state.reconnectAttempt
            )
        }
    }

    private func beginHID() throws {
        let created = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(created, Self.strictMatching())
        installCallbacks(on: created)

        let opened = IOHIDManagerOpen(created, IOOptionBits(kIOHIDOptionsTypeNone))
        guard opened == kIOReturnSuccess else {
            let code = Self.sanitizedIOReturn(opened)
            LidLog.sensor.error("hid manager open failed \(code, privacy: .public)")
            throw SensorError.hidSubsystemUnavailable
        }

        store.withLock { $0.manager = created }
        startRunLoop(for: created)

        if attachBestDevice() {
            return
        }

        store.withLock { state in
            state.state = .unavailable
            state.lastErrorCode = SensorError.unavailable.sanitizedCode
        }
        LidLog.sensor.info("lid angle sensor unavailable")
    }

    private func startRunLoop(for manager: IOHIDManager) {
        let ready = DispatchSemaphore(value: 0)
        let retainedManager = UncheckedHIDBox(value: manager)
        let thread = Thread { [weak self] in
            guard let self else { return }
            guard let loop = CFRunLoopGetCurrent() else {
                ready.signal()
                return
            }
            self.store.withLock { $0.runLoop = loop }
            IOHIDManagerScheduleWithRunLoop(retainedManager.value, loop, Self.runLoopMode)
            ready.signal()
            CFRunLoopRun()
            self.runLoopStopped.signal()
        }
        thread.name = "lid.hid"
        thread.qualityOfService = QualityOfService.userInitiated
        store.withLock { $0.runLoopThread = thread }
        thread.start()
        ready.wait()
    }

    private func installCallbacks(on manager: IOHIDManager) {
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceRemovalCallback(
            manager,
            { context, _, _, device in
                guard let context else { return }
                Unmanaged<IOKitLidAngleProvider>.fromOpaque(context).takeUnretainedValue()
                    .handleRemoval(device)
            },
            context
        )
        IOHIDManagerRegisterDeviceMatchingCallback(
            manager,
            { context, _, _, device in
                guard let context else { return }
                Unmanaged<IOKitLidAngleProvider>.fromOpaque(context).takeUnretainedValue()
                    .handleArrival(device)
            },
            context
        )
    }

    private func attachBestDevice() -> Bool {
        guard let manager = store.withLock({ $0.manager }) else { return false }
        if attachFirstValid(in: manager) {
            return true
        }
        IOHIDManagerSetDeviceMatching(manager, Self.fallbackMatching())
        return attachFirstValid(in: manager)
    }

    private func attachFirstValid(in manager: IOHIDManager) -> Bool {
        guard let devices = IOHIDManagerCopyDevices(manager) as NSSet? else {
            return false
        }
        for case let device as IOHIDDevice in devices {
            if openValidated(device) {
                return true
            }
        }
        return false
    }

    @discardableResult
    private func openValidated(_ device: IOHIDDevice) -> Bool {
        let opened = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        guard opened == kIOReturnSuccess else {
            store.withLock {
                $0.lastErrorCode = SensorError.deviceOpenFailed(code: Self.sanitizedIOReturn(opened)).sanitizedCode
            }
            return false
        }
        switch readParsed(from: device) {
        case .success(let parsed):
            remember(device: device)
            emit(parsed)
            return true
        case .failure(let error):
            IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
            store.withLock { $0.lastErrorCode = error.sanitizedCode }
            return false
        }
    }

    private func remember(device: IOHIDDevice) {
        store.withLock { state in
            if let current = state.device, !CFEqual(current, device) {
                IOHIDDeviceClose(current, IOOptionBits(kIOHIDOptionsTypeNone))
            }
            state.device = device
            state.hadValidatedDevice = true
            state.state = .available
            state.lastErrorCode = nil
            state.reconnectAttempt = 0
            state.consecutiveInvalidReads = 0
            state.lastVendorID = Self.intProperty(device, kIOHIDVendorIDKey)
            state.lastProductID = Self.intProperty(device, kIOHIDProductIDKey)
            state.lastUsagePage = Self.intProperty(device, kIOHIDPrimaryUsagePageKey)
                ?? Self.intProperty(device, kIOHIDDeviceUsagePageKey)
            state.lastUsage = Self.intProperty(device, kIOHIDPrimaryUsageKey)
                ?? Self.intProperty(device, kIOHIDDeviceUsageKey)
        }
        reconnectTask?.cancel()
        reconnectTask = nil
        LidLog.sensor.info("lid angle sensor attached")
    }

    private func handleArrival(_ device: IOHIDDevice) {
        let shouldAttach = store.withLock { $0.started && $0.device == nil }
        guard shouldAttach else { return }
        _ = openValidated(device)
    }

    private func handleRemoval(_ device: IOHIDDevice) {
        let isCurrent = store.withLock { state in
            state.device.map { CFEqual($0, device) } ?? false
        }
        guard isCurrent else { return }
        detachCurrentDevice(errorCode: "device_removed")
    }

    private func detachCurrentDevice(errorCode: String) {
        let shouldReconnect = store.withLock { state -> Bool in
            if let device = state.device {
                IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
            }
            state.device = nil
            state.lastErrorCode = errorCode
            state.state = state.hadValidatedDevice ? .reconnecting : .unavailable
            return state.started && state.hadValidatedDevice
        }
        LidLog.sensor.info("lid angle sensor detached \(errorCode, privacy: .public)")
        if shouldReconnect {
            scheduleReconnect()
        }
    }

    private func scheduleReconnect() {
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            await self?.reconnectLoop()
        }
    }

    private func reconnectLoop() async {
        while !Task.isCancelled {
            let snapshot = store.withLock { state -> (Bool, Bool, Int) in
                if state.started && state.device == nil {
                    state.reconnectAttempt += 1
                }
                return (state.started, state.device != nil, state.reconnectAttempt)
            }
            if !snapshot.0 || snapshot.1 {
                return
            }
            let attempt = max(snapshot.2 - 1, 0)
            LidLog.sensor.info("sensor reconnect backoff attempt=\(attempt, privacy: .public)")
            do {
                try await sleeper.sleep(for: timing.backoffDelay(forAttempt: attempt))
            } catch {
                return
            }
            if attachBestDevice() {
                return
            }
        }
    }

    private func pollLoop() async {
        while !Task.isCancelled {
            let snapshot = store.withLock { ($0.started, $0.device) }
            if !snapshot.0 {
                return
            }
            if let device = snapshot.1 {
                switch readParsed(from: device) {
                case .success(let parsed):
                    store.withLock { $0.consecutiveInvalidReads = 0 }
                    emit(parsed)
                case .failure(let error):
                    let failures = store.withLock { state -> Int in
                        state.consecutiveInvalidReads += 1
                        state.lastErrorCode = error.sanitizedCode
                        return state.consecutiveInvalidReads
                    }
                    LidLog.sensor.error("sensor read failed \(error.sanitizedCode, privacy: .public)")
                    if failures >= 3 {
                        detachCurrentDevice(errorCode: error.sanitizedCode)
                    }
                }
            }
            do {
                try await sleeper.sleep(for: timing.pollInterval)
            } catch {
                return
            }
        }
    }

    private func readParsed(from device: IOHIDDevice) -> Result<HIDAngleReportParser.Parsed, SensorError> {
        switch Self.readFeatureReport(from: device) {
        case .failure(let error):
            return .failure(error)
        case .success(let bytes):
            switch HIDAngleReportParser.parse(bytes) {
            case .success(let parsed):
                return .success(parsed)
            case .failure(let parseError):
                return .failure(.invalidReport(code: parseError.description))
            }
        }
    }

    private func emit(_ parsed: HIDAngleReportParser.Parsed) {
        let sample = LidAngleSample(
            degrees: parsed.degrees,
            collectedAtNanoseconds: clock.nowNanoseconds(),
            quality: parsed.quality
        )
        store.withLock { state in
            state.lastRawDegrees = parsed.degrees
            state.lastSample = sample
            if parsed.quality == .valid {
                state.state = .available
                state.lastErrorCode = nil
            }
        }
        continuation.yield(sample)
    }

    private func tearDownHID() {
        pollTask?.cancel()
        reconnectTask?.cancel()
        let snapshot = store.withLock { state -> (IOHIDManager?, IOHIDDevice?, CFRunLoop?) in
            let values = (state.manager, state.device, state.runLoop)
            state.device = nil
            state.manager = nil
            state.runLoop = nil
            return values
        }

        if let device = snapshot.1 {
            IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        if let manager = snapshot.0 {
            IOHIDManagerRegisterDeviceRemovalCallback(manager, nil, nil)
            IOHIDManagerRegisterDeviceMatchingCallback(manager, nil, nil)
            if let loop = snapshot.2 {
                let stop = DispatchSemaphore(value: 0)
                CFRunLoopPerformBlock(loop, Self.runLoopMode) {
                    IOHIDManagerUnscheduleFromRunLoop(manager, loop, Self.runLoopMode)
                    CFRunLoopStop(loop)
                    stop.signal()
                }
                CFRunLoopWakeUp(loop)
                _ = stop.wait(timeout: .now() + 1)
                _ = runLoopStopped.wait(timeout: .now() + 1)
            }
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        store.withLock { $0.runLoopThread = nil }
    }

    static func readFeatureReport(from device: IOHIDDevice) -> Result<[UInt8], SensorError> {
        var report = [UInt8](repeating: 0, count: LidHIDMatching.reportBufferLength)
        report[0] = HIDAngleReportParser.featureReportID
        var length = report.count
        let status: IOReturn = report.withUnsafeMutableBufferPointer { buffer in
            guard let pointer = buffer.baseAddress else {
                return kIOReturnError
            }
            var localLength = buffer.count
            let io = IOHIDDeviceGetReport(
                device,
                kIOHIDReportTypeFeature,
                LidHIDMatching.featureReportID,
                pointer,
                &localLength
            )
            length = localLength
            return io
        }
        guard status == kIOReturnSuccess else {
            return .failure(.reportFailed(code: sanitizedIOReturn(status)))
        }
        return .success(Array(report.prefix(max(length, 0))))
    }

    private static var runLoopMode: CFString {
        CFRunLoopMode.defaultMode.rawValue as CFString
    }

    private static func strictMatching() -> CFDictionary {
        [
            kIOHIDVendorIDKey as String: LidHIDMatching.appleVendorID,
            kIOHIDProductIDKey as String: LidHIDMatching.sensorHubProductID,
            kIOHIDDeviceUsagePageKey as String: LidHIDMatching.sensorUsagePage,
            kIOHIDDeviceUsageKey as String: LidHIDMatching.orientationUsage,
        ] as CFDictionary
    }

    fileprivate static func fallbackMatching() -> CFDictionary {
        [
            kIOHIDDeviceUsagePageKey as String: LidHIDMatching.sensorUsagePage,
            kIOHIDDeviceUsageKey as String: LidHIDMatching.orientationUsage,
        ] as CFDictionary
    }

    static func sanitizedIOReturn(_ value: IOReturn) -> String {
        String(format: "io_0x%08x", UInt32(bitPattern: value))
    }

    static func intProperty(_ device: IOHIDDevice, _ key: String) -> UInt32? {
        guard let number = IOHIDDeviceGetProperty(device, key as CFString) as? NSNumber else {
            return nil
        }
        return number.uint32Value
    }
}

private struct UncheckedHIDBox<Value>: @unchecked Sendable {
    var value: Value
}

public enum IOKitLidAngleProbe {
    public static func listCandidates() -> [HIDDeviceCandidate] {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(manager, IOKitLidAngleProvider.fallbackMatching())
        let opened = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        defer {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        guard opened == kIOReturnSuccess else {
            return []
        }
        guard let devices = IOHIDManagerCopyDevices(manager) as NSSet? else {
            return []
        }
        var candidates: [HIDDeviceCandidate] = []
        for case let device as IOHIDDevice in devices {
            var candidate = HIDDeviceCandidate(
                vendorID: IOKitLidAngleProvider.intProperty(device, kIOHIDVendorIDKey),
                productID: IOKitLidAngleProvider.intProperty(device, kIOHIDProductIDKey),
                usagePage: IOKitLidAngleProvider.intProperty(device, kIOHIDPrimaryUsagePageKey)
                    ?? IOKitLidAngleProvider.intProperty(device, kIOHIDDeviceUsagePageKey),
                usage: IOKitLidAngleProvider.intProperty(device, kIOHIDPrimaryUsageKey)
                    ?? IOKitLidAngleProvider.intProperty(device, kIOHIDDeviceUsageKey),
                builtIn: IOKitLidAngleProvider.intProperty(device, kIOHIDBuiltInKey).map { $0 != 0 }
            )
            let openedDevice = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
            if openedDevice == kIOReturnSuccess {
                if case .success(let bytes) = IOKitLidAngleProvider.readFeatureReport(from: device),
                   case .success = HIDAngleReportParser.parse(bytes) {
                    candidate.validated = true
                }
                IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
            }
            candidates.append(candidate)
        }
        return candidates
    }
}
#endif
