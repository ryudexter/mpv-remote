import Foundation
import Network
import RemoteProtocol

/// The computer this phone controls, remembered between launches.
struct SavedComputer: Codable, Equatable {
    enum Address: Codable, Equatable {
        /// Found over Bonjour; resolved fresh on every connection, so a
        /// changing IP address doesn't matter.
        case bonjour(name: String)
        case host(String, port: UInt16)
    }

    var name: String
    var address: Address
    /// Issued by the companion when pairing; nil until then.
    var token: String?

    var endpoint: NWEndpoint {
        switch address {
        case .bonjour(let name):
            .service(name: name, type: RemoteService.bonjourType, domain: "local.", interface: nil)
        case .host(let host, let port):
            .hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port) ?? 7655)
        }
    }

    /// Accepts "192.168.1.20", "studio.local" or either with ":port".
    init?(manualAddress: String) {
        let text = manualAddress.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        var host = text
        var port = RemoteService.defaultPort
        if let colon = text.lastIndex(of: ":"), let parsed = UInt16(text[text.index(after: colon)...]) {
            host = String(text[..<colon])
            port = parsed
        }
        self.init(name: host, address: .host(host, port: port))
    }

    init(name: String, address: Address, token: String? = nil) {
        self.name = name
        self.address = address
        self.token = token
    }

    private static let defaultsKey = "savedComputer"

    static func load() -> SavedComputer? {
        UserDefaults.standard.data(forKey: defaultsKey).flatMap { try? JSONDecoder().decode(SavedComputer.self, from: $0) }
    }

    func save() {
        UserDefaults.standard.set(try? JSONEncoder().encode(self), forKey: Self.defaultsKey)
    }

    static func forget() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }
}
