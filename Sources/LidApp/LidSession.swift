import AppKit
import Foundation
import LidCore
import Observation

@MainActor
@Observable
final class LidSession {
    var settings: AppSettings
    var sensorState: SensorState = .stopped
    var rawAngle: Double?
    var filteredAngle: Double?
    var automationState: AutomationDisplayState = .off
    var resolutionTitle = "Starting"
    var snooze = SnoozeState.inactive
    var events: [DiagnosticEvent] = []
    var host = HostIdentity.current()
    var sensorDiagnostics: SensorDiagnostics?
    var accessibilityStatus: PermissionStatus = .denied
    var simulatedAngle: Double = 90
    var useSimulator: Bool
    var overlayVisible = false
    var lastErrorCode: String?
    var showOnboarding = false

    private let settingsStore = SettingsStore()
    private let diagnosticsStore = DiagnosticsStore()
    private let engine = AutomationEngine()
    private let overlay = OverlayController()
    private let locker = CGEventScreenLocker()
    private let media = AppleScriptMediaController()
    private var executor: ActionExecutor!
    private var coordinator: SensorCoordinator?
    private var provider: (any LidAngleProviding)?
    private var simulatedProvider: SimulatedLidAngleProvider?
    private var runTask: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []

    init() {
        settings = .default
        useSimulator = false
        executor = ActionExecutor(overlay: overlay, locker: locker, media: media)
        LidWindowPresenter.shared.attach(self)
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    func openSettings() {
        LidWindowPresenter.shared.show(.settings)
    }

    func openDiagnostics() {
        LidWindowPresenter.shared.show(.diagnostics)
    }

    func openOnboarding() {
        LidWindowPresenter.shared.show(.onboarding)
    }

    func closeOnboarding() {
        LidWindowPresenter.shared.close(.onboarding)
    }

    func start() async {
        settings = await settingsStore.current()
        if !settings.startEnabledAfterLaunch {
            settings.automationEnabled = false
        }
        accessibilityStatus = await locker.permissionStatus()
        installObservers()
        await startPipeline()
        showOnboarding = !settings.completedOnboarding
    }

    func shutdown() async {
        runTask?.cancel()
        runTask = nil
        await coordinator?.stop()
        await overlay.hide()
        overlayVisible = false
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers = []
    }

    func setAutomationEnabled(_ enabled: Bool) async {
        var next = settings
        next.automationEnabled = enabled
        try? await settingsStore.replace(next)
        settings = await settingsStore.current()
        if !enabled {
            await overlay.hide()
            overlayVisible = false
        }
        await record("automation_\(enabled ? "on" : "off")")
    }

    func applySnooze(_ option: SnoozeOption?) async {
        let now = Date()
        await engine.setSnooze(option, now: now)
        snooze = await engine.currentSnooze()
        if option != nil {
            await overlay.hide()
            overlayVisible = false
            await record("snooze_started")
        } else {
            await record("snooze_cleared")
        }
    }

    func updateSettings(_ mutate: @escaping (inout AppSettings) throws -> Void) async {
        do {
            var next = settings
            try mutate(&next)
            try await settingsStore.replace(next)
            settings = await settingsStore.current()
            LoginItem.setEnabled(settings.launchAtLogin)
            if settings.lock.enabled {
                accessibilityStatus = await locker.permissionStatus()
            }
        } catch {
            await record("settings_rejected", detail: String(describing: error))
        }
    }

    func requestLockPermission() async {
        locker.requestPermission()
        accessibilityStatus = await locker.permissionStatus()
    }

    func testOverlay() async {
        await overlay.show()
        overlayVisible = true
        try? await Task.sleep(for: .seconds(2))
        await overlay.hide()
        overlayVisible = false
    }

    func testLock() async {
        await requestLockPermission()
        guard accessibilityStatus == .granted else { return }
        try? await locker.lock()
    }

    func finishOnboarding() async {
        await updateSettings { $0.completedOnboarding = true }
    }

    func setSimulatedAngle(_ value: Double) async {
        simulatedAngle = value
        await simulatedProvider?.setAngle(value)
    }

    func toggleSimulator(_ enabled: Bool) async {
        useSimulator = enabled
        await startPipeline()
    }

    func exportDiagnostics() async -> URL? {
        do {
            let data = try await diagnosticsStore.exportJSON()
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("lid-diagnostics.json")
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    var menuAngleText: String {
        if sensorState == .unavailable || sensorState == .stopped {
            return "Lid"
        }
        guard let filteredAngle, settings.showAngleInMenuBar else {
            return "Lid"
        }
        return "\(Int(filteredAngle.rounded()))°"
    }

    var nextActionText: String {
        guard let next = settings.nextDownwardAction else {
            return "No actions enabled"
        }
        switch next.0 {
        case .privacyOverlay: return "Privacy at \(Int(next.1))°"
        case .lock: return "Lock at \(Int(next.1))°"
        case .mediaPause: return "Media pause at \(Int(next.1))°"
        }
    }

    var sensorStateText: String {
        switch sensorState {
        case .available: "Available"
        case .unavailable: "Sensor unavailable"
        case .reconnecting: "Reconnecting"
        case .permissionBlocked: "Permission blocked"
        case .stopped: "Stopped"
        }
    }

    private func startPipeline() async {
        runTask?.cancel()
        await coordinator?.stop()

        let nextProvider: any LidAngleProviding
        if useSimulator {
            let simulated = SimulatedLidAngleProvider(
                configuration: SimulatedLidConfiguration(pollInterval: .milliseconds(100))
            )
            simulatedProvider = simulated
            await simulated.setAngle(simulatedAngle)
            nextProvider = simulated
        } else {
            simulatedProvider = nil
            nextProvider = IOKitLidAngleProvider()
        }
        provider = nextProvider
        let coordinator = SensorCoordinator(provider: nextProvider)
        self.coordinator = coordinator
        do {
            try await coordinator.start()
        } catch {
            sensorState = .unavailable
            await record("sensor_start_failed", detail: error.sanitizedCodeIfPossible)
            return
        }
        await refreshDiagnostics()
        if !useSimulator, sensorState == .unavailable {
            await record("sensor_unavailable")
        }

        runTask = Task { [weak self] in
            guard let self else { return }
            for await sample in coordinator.readings {
                if Task.isCancelled { return }
                await self.handle(sample)
            }
        }
    }

    private func handle(_ sample: LidAngleSample) async {
        await refreshDiagnostics()
        rawAngle = sample.quality == .invalid ? nil : sample.degrees
        let diagnostics = await coordinator?.diagnostics()
        let stale = diagnostics?.lastErrorCode == "stale_reading"
        lastErrorCode = diagnostics?.lastErrorCode
        let foreground = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let snapshot = await engine.evaluate(
            sample: sample,
            isStale: stale,
            settings: settings,
            foregroundBundleID: foreground,
            nowMonotonic: sample.collectedAtNanoseconds,
            nowWall: Date(),
            calendar: .current
        )
        filteredAngle = snapshot.filtered?.degrees
        automationState = snapshot.displayState
        resolutionTitle = snapshot.decision.resolution.title
        snooze = snapshot.snooze
        if !snapshot.decision.intents.isEmpty {
            let results = await executor.execute(
                snapshot.decision.intents,
                context: ActionContext(settings: settings, foregroundBundleID: foreground)
            )
            overlayVisible = await overlay.isVisible()
            for (intent, result) in results {
                await record(code(for: intent, result: result), bundleIdentifier: foreground)
            }
        }
    }

    private func refreshDiagnostics() async {
        sensorDiagnostics = await coordinator?.diagnostics()
        sensorState = sensorDiagnostics?.state ?? .unavailable
        events = await diagnosticsStore.recent().reversed()
    }

    private func record(_ code: String, detail: String? = nil, bundleIdentifier: String? = nil) async {
        let event = DiagnosticEvent(at: Date(), code: code, detail: detail, bundleIdentifier: bundleIdentifier)
        await diagnosticsStore.record(event)
        events = await diagnosticsStore.recent().reversed()
    }

    private func installObservers() {
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                await self?.record("system_wake")
            }
        })
        observers.append(NotificationCenter.default.addObserver(forName: .NSSystemTimeZoneDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                await self?.record("timezone_change")
            }
        })
        observers.append(NotificationCenter.default.addObserver(forName: NSNotification.Name.NSSystemClockDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                await self?.record("clock_change")
            }
        })
    }

    private func code(for intent: ActionIntent, result: ActionResult) -> String {
        switch (intent, result) {
        case (.apply(let id), .succeeded): "action_\(id.rawValue)_succeeded"
        case (.apply(let id), .submittedUnverified): "action_\(id.rawValue)_submitted"
        case (.apply(let id), .denied): "action_\(id.rawValue)_denied"
        case (.apply(let id), .skipped(let reason)): "action_\(id.rawValue)_\(reason.rawValue)"
        case (.apply(let id), .unsupported): "action_\(id.rawValue)_unsupported"
        case (.apply(let id), .failed(let code)): "action_\(id.rawValue)_\(code)"
        case (.reset(let id), _): "reset_\(id.rawValue)"
        }
    }
}

private extension Error {
    var sanitizedCodeIfPossible: String {
        if let sensor = self as? SensorError {
            return sensor.sanitizedCode
        }
        return "error"
    }
}
