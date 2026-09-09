/// Source of lid-angle samples. Hardware and simulation both implement this.
///
/// The stream stays open across `start()` / `stop()`. Consumers must not assume
/// a finished stream means the sensor vanished.
public protocol LidAngleProviding: Sendable {
    var readings: AsyncStream<LidAngleSample> { get }
    func start() async throws
    func stop() async
    func diagnostics() async -> SensorDiagnostics
}
