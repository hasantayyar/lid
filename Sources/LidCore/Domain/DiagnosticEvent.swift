import Foundation

public struct DiagnosticEvent: Sendable, Hashable, Codable, Equatable, Identifiable {
    public var id: UUID
    public var at: Date
    public var code: String
    public var detail: String?
    public var bundleIdentifier: String?

    public init(
        id: UUID = UUID(),
        at: Date,
        code: String,
        detail: String? = nil,
        bundleIdentifier: String? = nil
    ) {
        self.id = id
        self.at = at
        self.code = code
        self.detail = detail
        self.bundleIdentifier = bundleIdentifier
    }
}
