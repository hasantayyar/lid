public struct SensorDiagnostics: Sendable, Hashable, Codable, Equatable {
    public var adapterName: String
    public var state: SensorState
    public var host: HostIdentity
    public var vendorID: UInt32?
    public var productID: UInt32?
    public var usagePage: UInt32?
    public var usage: UInt32?
    public var lastRawDegrees: Double?
    public var lastNormalizedDegrees: Double?
    public var lastQuality: SampleQuality?
    public var lastSuccessfulReadingNanoseconds: UInt64?
    public var lastErrorCode: String?
    public var reconnectAttempt: Int

    public init(
        adapterName: String,
        state: SensorState,
        host: HostIdentity,
        vendorID: UInt32? = nil,
        productID: UInt32? = nil,
        usagePage: UInt32? = nil,
        usage: UInt32? = nil,
        lastRawDegrees: Double? = nil,
        lastNormalizedDegrees: Double? = nil,
        lastQuality: SampleQuality? = nil,
        lastSuccessfulReadingNanoseconds: UInt64? = nil,
        lastErrorCode: String? = nil,
        reconnectAttempt: Int = 0
    ) {
        self.adapterName = adapterName
        self.state = state
        self.host = host
        self.vendorID = vendorID
        self.productID = productID
        self.usagePage = usagePage
        self.usage = usage
        self.lastRawDegrees = lastRawDegrees
        self.lastNormalizedDegrees = lastNormalizedDegrees
        self.lastQuality = lastQuality
        self.lastSuccessfulReadingNanoseconds = lastSuccessfulReadingNanoseconds
        self.lastErrorCode = lastErrorCode
        self.reconnectAttempt = reconnectAttempt
    }

    public var exportedFields: [String] {
        [
            "adapterName",
            "state",
            "host.modelIdentifier",
            "host.macOSVersion",
            "host.operatingSystemVersionString",
            "host.architecture",
            "vendorID",
            "productID",
            "usagePage",
            "usage",
            "lastRawDegrees",
            "lastNormalizedDegrees",
            "lastQuality",
            "lastSuccessfulReadingNanoseconds",
            "lastErrorCode",
            "reconnectAttempt",
        ]
    }
}
