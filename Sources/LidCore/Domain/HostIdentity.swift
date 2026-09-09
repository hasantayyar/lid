import Foundation

public struct HostIdentity: Sendable, Hashable, Codable, Equatable {
    public var modelIdentifier: String
    public var macOSVersion: String
    public var operatingSystemVersionString: String
    public var architecture: String

    public init(
        modelIdentifier: String,
        macOSVersion: String,
        operatingSystemVersionString: String,
        architecture: String
    ) {
        self.modelIdentifier = modelIdentifier
        self.macOSVersion = macOSVersion
        self.operatingSystemVersionString = operatingSystemVersionString
        self.architecture = architecture
    }

    public static func current() -> HostIdentity {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return HostIdentity(
            modelIdentifier: sysctlString("hw.model") ?? "unknown",
            macOSVersion: "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)",
            operatingSystemVersionString: ProcessInfo.processInfo.operatingSystemVersionString,
            architecture: sysctlString("hw.machine") ?? "unknown"
        )
    }
}

private func sysctlString(_ name: String) -> String? {
    var size = 0
    guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else {
        return nil
    }
    var buffer = [CChar](repeating: 0, count: size)
    guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else {
        return nil
    }
    let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
    return String(decoding: bytes, as: UTF8.self)
}
