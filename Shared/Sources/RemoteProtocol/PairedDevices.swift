import Foundation

/// A phone the companion has given a token to. This is the shape of one entry
/// in `paired-devices.json`; `id` is new, and files without it still load.
public struct PairedDevice: Codable, Equatable, Sendable {
    public var name: String
    public var token: String
    public var pairedAt: Date
    /// Identifies the phone's install of the app, from apps that send one.
    public var id: String?

    public init(name: String, token: String, pairedAt: Date, id: String? = nil) {
        self.name = name
        self.token = token
        self.pairedAt = pairedAt
        self.id = id
    }
}

/// The phones the companion lets in.
public struct PairedDevices: Sendable {
    public private(set) var all: [PairedDevice]

    public init(_ all: [PairedDevice] = []) {
        self.all = all
    }

    public func name(forToken token: String) -> String? {
        all.first { $0.token == token }?.name
    }

    /// Adds a pairing. A phone that sends an `id` and pairs again, because it
    /// lost its token or chose the computer under another name, replaces its
    /// earlier entry instead of adding a second. Names can't tell phones apart
    /// (iOS gives every iPhone the same generic one), so without an `id` the
    /// entry is always added. Returns how many earlier entries it replaced.
    @discardableResult
    public mutating func add(_ device: PairedDevice) -> Int {
        let count = all.count
        if let id = device.id {
            all.removeAll { $0.id == id }
        }
        all.append(device)
        return count + 1 - all.count
    }
}
