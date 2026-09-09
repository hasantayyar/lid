public struct HIDDeviceCandidate: Sendable, Hashable, Codable, Equatable {
    public var vendorID: UInt32?
    public var productID: UInt32?
    public var usagePage: UInt32?
    public var usage: UInt32?
    public var builtIn: Bool?
    public var validated: Bool

    public init(
        vendorID: UInt32? = nil,
        productID: UInt32? = nil,
        usagePage: UInt32? = nil,
        usage: UInt32? = nil,
        builtIn: Bool? = nil,
        validated: Bool = false
    ) {
        self.vendorID = vendorID
        self.productID = productID
        self.usagePage = usagePage
        self.usage = usage
        self.builtIn = builtIn
        self.validated = validated
    }
}
