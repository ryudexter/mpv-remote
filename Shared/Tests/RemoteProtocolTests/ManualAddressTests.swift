import Testing
@testable import RemoteProtocol

struct ManualAddressTests {
    private func parse(_ text: String) -> (String, UInt16)? {
        ManualAddress(text).map { ($0.host, $0.port) }
    }

    @Test func ipv4AndNames() {
        #expect(parse("192.168.1.20")?.0 == "192.168.1.20")
        #expect(parse("192.168.1.20")?.1 == 7655)
        #expect(parse("192.168.1.20:7700")?.1 == 7700)
        #expect(parse("studio.local")?.0 == "studio.local")
        #expect(parse("studio.local:9")?.0 == "studio.local")
        #expect(parse("studio.local:9")?.1 == 9)
        #expect(parse("  studio.local \n")?.0 == "studio.local")
    }

    @Test func bareIPv6UsesTheDefaultPort() {
        for text in ["::1", "fe80::1", "2001:db8::1", "2001:db8:0:0:0:0:0:1", "fe80::1%en0"] {
            let result = parse(text)
            #expect(result?.0 == text, "\(text)")
            #expect(result?.1 == 7655, "\(text)")
        }
    }

    @Test func bracketedIPv6TakesAPort() {
        #expect(parse("[::1]")?.0 == "::1")
        #expect(parse("[::1]")?.1 == 7655)
        #expect(parse("[::1]:7700")?.0 == "::1")
        #expect(parse("[::1]:7700")?.1 == 7700)
        #expect(parse("[fe80::1%en0]:7700")?.0 == "fe80::1%en0")
        #expect(parse("[2001:db8::1]:65535")?.1 == 65535)
    }

    @Test func nonsenseIsRefused() {
        let bad = ["", "   ", ":7655", "host:", "host:abc", "host:0", "host:65536", "host:-1", "host:+80",
                   "a b", "1:2:3", ":::", "fe80::g", "fe80::1%", "[::1", "[::1]7700", "[::1]:", "[::1]:x", "[host]:80",
                   "[192.168.1.20]:80", "http://studio.local", "host:80:90"]
        for text in bad {
            #expect(ManualAddress(text) == nil, "\(text)")
        }
    }
}

struct ManualAddressURLTests {
    private func url(_ text: String) -> String? {
        ManualAddress(text)?.webSocketURL?.absoluteString
    }

    @Test func urlsForEachKindOfAddress() {
        #expect(url("192.168.1.20") == "ws://192.168.1.20:7655")
        #expect(url("192.168.1.20:7700") == "ws://192.168.1.20:7700")
        #expect(url("studio.local") == "ws://studio.local:7655")
        #expect(url("fe80::1") == "ws://[fe80::1]:7655")
        #expect(url("[::1]:7700") == "ws://[::1]:7700")
        #expect(url("fe80::1%en0") == "ws://[fe80::1%25en0]:7655")
    }
}
