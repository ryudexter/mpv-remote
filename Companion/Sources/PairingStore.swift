import Foundation

/// Decides which phones may control mpv. A phone proves itself once with the
/// 4-digit code printed by the companion and gets a long random token back,
/// which it presents on every later connection.
@MainActor
final class PairingStore {
    private struct Device: Codable {
        var name: String
        var token: String
        var pairedAt: Date
    }

    private(set) var code = PairingStore.makeCode()
    private var devices: [Device]
    private var failedAttempts = 0
    private let fileURL: URL

    init() {
        fileURL = URL.applicationSupportDirectory.appending(path: "MPV Remote/paired-devices.json")
        devices = (try? JSONDecoder().decode([Device].self, from: Data(contentsOf: fileURL))) ?? []
    }

    func deviceName(forToken token: String) -> String? {
        devices.first { $0.token == token }?.name
    }

    /// Returns a new token if `attempt` matches the current code.
    func pair(code attempt: String, deviceName: String) -> String? {
        guard attempt == code else {
            failedAttempts += 1
            // Four digits are only 10,000 guesses; don't let anyone make many of them.
            if failedAttempts >= 5 {
                rotateCode()
                log("Too many wrong pairing codes. New code: \(code)")
            }
            return nil
        }
        let token = (0..<32).map { _ in String(format: "%02x", UInt8.random(in: .min ... .max)) }.joined()
        devices.append(Device(name: deviceName, token: token, pairedAt: .now))
        save()
        rotateCode()
        return token
    }

    private func rotateCode() {
        code = Self.makeCode()
        failedAttempts = 0
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(devices).write(to: fileURL, options: .atomic)
        } catch {
            log("Could not save paired devices: \(error.localizedDescription)")
        }
    }

    private static func makeCode() -> String {
        String(format: "%04d", Int.random(in: 0...9999))
    }
}
