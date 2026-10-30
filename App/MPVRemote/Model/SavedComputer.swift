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
        /// The built-in demo; there's nothing to connect to.
        case demo
    }

    var name: String
    var address: Address
    /// Issued by the companion when pairing; nil until then.
    var token: String?

    var endpoint: NWEndpoint? {
        switch address {
        case .bonjour(let name):
            .service(name: name, type: RemoteService.bonjourType, domain: "local.", interface: nil)
        case .host(let host, let port):
            .hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port) ?? 7655)
        case .demo:
            nil
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
    /// Every token this phone has been given, by computer name. Kept apart from
    /// the chosen computer, so choosing a computer again, or switching between
    /// two, never asks for a new code.
    private static let tokensKey = "pairingTokens"

    static func load() -> SavedComputer? {
        UserDefaults.standard.data(forKey: defaultsKey).flatMap { try? JSONDecoder().decode(SavedComputer.self, from: $0) }
    }

    func save() {
        UserDefaults.standard.set(try? JSONEncoder().encode(self), forKey: Self.defaultsKey)
        if let token { Self.tokens[name] = token }
    }

    /// Stops using this computer. Its token is kept, for if it's chosen again.
    static func forget() {
        // Installs from before tokens were kept apart only have it here.
        if let saved = load(), let token = saved.token { tokens[saved.name] = token }
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }

    /// The token from an earlier pairing with the computer called `name`.
    static func token(for name: String) -> String? {
        tokens[name]
    }

    /// Drops a token the computer no longer accepts.
    static func forgetToken(for name: String) {
        tokens[name] = nil
    }

    /// Drops a token wherever it's kept: a computer chosen under two names, such
    /// as the address typed in and the name it answered with, has it under both.
    static func forgetToken(_ token: String) {
        tokens = tokens.filter { $0.value != token }
    }

    /// Tells the companion which phone is pairing, so pairing again replaces the
    /// first time instead of adding to it. Made once per install.
    static var deviceID: String {
        if let id = UserDefaults.standard.string(forKey: deviceIDKey) { return id }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: deviceIDKey)
        return id
    }

    private static let deviceIDKey = "deviceID"

    private static var tokens: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: tokensKey) as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: tokensKey) }
    }
}
