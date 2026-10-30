import Foundation

/// A computer's address as someone types it: "192.168.1.20", "studio.local",
/// either with ":7700" after it, an IPv6 address such as "fe80::1" (which has
/// no port; it would be ambiguous), or an IPv6 address in brackets with an
/// optional port, "[fe80::1]:7700". The brackets are what tell the address's
/// own colons from the port's.
public struct ManualAddress: Equatable, Sendable {
    /// Without brackets, as `NWEndpoint.Host` wants it.
    public let host: String
    public let port: UInt16

    public init?(_ text: String) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !text.contains(where: \.isWhitespace) else { return nil }

        if text.hasPrefix("[") {
            guard let close = text.firstIndex(of: "]") else { return nil }
            let host = String(text[text.index(after: text.startIndex)..<close])
            guard Self.isIPv6(host) else { return nil }
            let rest = text[text.index(after: close)...]
            if rest.isEmpty {
                self.init(host: host, port: RemoteService.defaultPort)
            } else if rest.hasPrefix(":"), let port = Self.port(rest.dropFirst()) {
                self.init(host: host, port: port)
            } else {
                return nil
            }
        } else if text.filter({ $0 == ":" }).count > 1 {
            // More than one colon and no brackets: an IPv6 address, all of it.
            guard Self.isIPv6(text) else { return nil }
            self.init(host: text, port: RemoteService.defaultPort)
        } else if let colon = text.firstIndex(of: ":") {
            let host = String(text[..<colon])
            guard !host.isEmpty, let port = Self.port(text[text.index(after: colon)...]) else { return nil }
            self.init(host: host, port: port)
        } else {
            self.init(host: text, port: RemoteService.defaultPort)
        }
    }

    public init(host: String, port: UInt16) {
        self.host = host
        self.port = port
    }

    /// The address as a `ws://` URL. Network.framework can't open a WebSocket
    /// to a host and port when the host is an IP address (it fails with "unable
    /// to create url endpoint"), but it can when given the URL, whatever the host.
    public var webSocketURL: URL? {
        var components = URLComponents()
        components.scheme = "ws"
        if host.contains(":") {
            // An IPv6 address goes in brackets, and its "%" (before an interface name) is escaped.
            components.percentEncodedHost = "[" + host.replacingOccurrences(of: "%", with: "%25") + "]"
        } else {
            components.host = host
        }
        components.port = Int(port)
        return components.url
    }

    private static func port(_ digits: Substring) -> UInt16? {
        guard !digits.isEmpty, digits.allSatisfy({ ("0"..."9").contains($0) }) else { return nil }
        return UInt16(digits).flatMap { $0 > 0 ? $0 : nil }
    }

    /// An IPv6 address, optionally followed by "%" and the interface it's on
    /// (link-local addresses need one).
    private static func isIPv6(_ text: String) -> Bool {
        let parts = text.split(separator: "%", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count <= 2, !(parts.count == 2 && parts[1].isEmpty) else { return false }
        var address = in6_addr()
        return inet_pton(AF_INET6, String(parts[0]), &address) == 1
    }
}
