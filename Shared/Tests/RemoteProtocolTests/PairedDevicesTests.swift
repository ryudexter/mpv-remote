import Foundation
import Testing
@testable import RemoteProtocol

struct PairedDevicesTests {
    private func device(_ name: String, token: String, id: String? = nil) -> PairedDevice {
        PairedDevice(name: name, token: token, pairedAt: Date(timeIntervalSinceReferenceDate: 100), id: id)
    }

    @Test func pairingAgainWithTheSameIDReplacesTheEntry() {
        var devices = PairedDevices()
        devices.add(device("iPhone", token: "old", id: "A"))
        let replaced = devices.add(device("iPhone", token: "new", id: "A"))
        #expect(replaced == 1)
        #expect(devices.all.count == 1)
        #expect(devices.name(forToken: "old") == nil)
        #expect(devices.name(forToken: "new") == "iPhone")
    }

    @Test func twoPhonesWithTheSameNameStayApart() {
        var devices = PairedDevices()
        devices.add(device("iPhone", token: "one", id: "A"))
        devices.add(device("iPhone", token: "two", id: "B"))
        #expect(devices.all.count == 2)
        #expect(devices.name(forToken: "one") != nil)
        #expect(devices.name(forToken: "two") != nil)
    }

    @Test func phonesWithoutAnIDAreAlwaysAdded() {
        // Older apps send none, and a name alone can't tell two phones apart.
        var devices = PairedDevices()
        devices.add(device("iPhone", token: "one"))
        let replaced = devices.add(device("iPhone", token: "two"))
        #expect(replaced == 0)
        #expect(devices.all.count == 2)
    }

    @Test func anIDlessEntryIsNotReplacedByAnIDedOne() {
        var devices = PairedDevices()
        devices.add(device("iPhone", token: "legacy"))
        devices.add(device("iPhone", token: "new", id: "A"))
        #expect(devices.all.count == 2)
    }

    @Test func filesFromBeforeIDsStillLoadAndRoundTrip() throws {
        let old = #"[{"name":"iPad","token":"abc","pairedAt":813945398.95}]"#
        let loaded = try JSONDecoder().decode([PairedDevice].self, from: Data(old.utf8))
        #expect(loaded.count == 1)
        #expect(loaded[0].id == nil)
        // Saved again, an entry without an id doesn't gain a field an older companion would choke on.
        let saved = String(decoding: try JSONEncoder().encode(loaded), as: UTF8.self)
        #expect(!saved.contains("\"id\""))
    }
}

struct PairMessageCompatibilityTests {
    @Test func aPairFromAnOlderAppStillDecodes() throws {
        let json = #"{"pair":{"code":"1234","deviceName":"iPhone"}}"#
        let message = try JSONDecoder().decode(ClientMessage.self, from: Data(json.utf8))
        guard case .pair(let code, let name, let id) = message else {
            Issue.record("not a pair message")
            return
        }
        #expect(code == "1234" && name == "iPhone" && id == nil)
    }

    @Test func aPairWithAnIDDecodesAndOlderCompanionsIgnoreTheExtraKey() throws {
        let json = #"{"pair":{"code":"1234","deviceName":"iPhone","deviceID":"X"}}"#
        let message = try JSONDecoder().decode(ClientMessage.self, from: Data(json.utf8))
        guard case .pair(_, _, let id) = message else {
            Issue.record("not a pair message")
            return
        }
        #expect(id == "X")
    }

    @Test func withoutAnIDTheMessageIsByteForByteTheOldOne() throws {
        let data = try JSONEncoder().encode(ClientMessage.pair(code: "1234", deviceName: "iPhone"))
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: [String: String]])
        #expect(object["pair"] == ["code": "1234", "deviceName": "iPhone"])
    }
}
