import Foundation

public actor DiagnosticsStore {
    public static let exportedFields = [
        "at",
        "code",
        "detail",
        "bundleIdentifier",
    ]

    private var events: [DiagnosticEvent] = []
    private let limit: Int

    public init(limit: Int = 200) {
        self.limit = limit
    }

    public func record(_ event: DiagnosticEvent) {
        events.append(event)
        if events.count > limit {
            events.removeFirst(events.count - limit)
        }
    }

    public func recent() -> [DiagnosticEvent] {
        events
    }

    public func exportJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(events)
    }
}
