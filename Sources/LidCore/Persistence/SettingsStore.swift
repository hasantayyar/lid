import Foundation

public actor SettingsStore {
    public static let maximumImportBytes = 64 * 1024
    private static let defaultsKey = "app.lid.settings"

    private let defaults: UserDefaults
    private var settings: AppSettings

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.defaultsKey),
           let decoded = try? SettingsMigrator.decode(data) {
            settings = decoded
        } else {
            settings = .default
        }
        if !settings.startEnabledAfterLaunch {
            settings.automationEnabled = false
        }
    }

    public func current() -> AppSettings {
        settings
    }

    public func update(_ mutate: (inout AppSettings) throws -> Void) throws {
        var next = settings
        try mutate(&next)
        try next.validate()
        settings = next
        persist()
    }

    public func replace(_ next: AppSettings) throws {
        try next.validate()
        settings = next
        persist()
    }

    public func exportJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(settings)
    }

    public func importJSON(_ data: Data) throws {
        guard data.count <= Self.maximumImportBytes else {
            throw SettingsValidationError.payloadTooLarge
        }
        let imported = try SettingsMigrator.decode(data)
        try replace(imported)
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(settings)
            defaults.set(data, forKey: Self.defaultsKey)
        } catch {
            LidLog.persistence.error("settings persist failed")
        }
    }
}

public enum SettingsMigrator {
    public static func decode(_ data: Data) throws -> AppSettings {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let dictionary = object as? [String: Any] else {
            throw SettingsValidationError.invalidJSON
        }
        let rawVersion = dictionary["schemaVersion"] as? Int ?? 1
        guard let version = SettingsSchemaVersion(rawValue: rawVersion) else {
            throw SettingsValidationError.unsupportedSchema(rawVersion)
        }
        _ = version
        do {
            return try JSONDecoder().decode(AppSettings.self, from: data)
        } catch {
            throw SettingsValidationError.invalidJSON
        }
    }
}
