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
    private var announced: (code: String, at: Date)?
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
                announceCode(reason: "Too many wrong pairing codes.")
            }
            return nil
        }
        let token = (0..<32).map { _ in String(format: "%02x", UInt8.random(in: .min ... .max)) }.joined()
        devices.append(Device(name: deviceName, token: token, pairedAt: .now))
        save()
        rotateCode()
        return token
    }

    /// Called with each code worth showing someone, e.g. on mpv's own screen.
    var onAnnounce: ((String) -> Void)?

    /// Logs the code and shows it as a notification, since the companion
    /// usually runs in the background with no terminal anyone is looking at.
    func announceCode(reason: String) {
        log("\(reason) Pairing code: \(code)")
        // A phone that reconnects while still unpaired shouldn't bring up the same code again.
        if let announced, announced.code == code, Date.now.timeIntervalSince(announced.at) < 60 { return }
        announced = (code, .now)
        let notification = Process()
        notification.executableURL = URL(filePath: "/usr/bin/osascript")
        // Passed as arguments rather than spliced into the script, so no quoting can break it.
        notification.arguments = [
            "-e", "on run argv", "-e", "display notification (item 1 of argv) with title (item 2 of argv)", "-e", "end run",
            "Enter \(code) on your iPhone.", "MPV Remote pairing code",
        ]
        try? notification.run()
        onAnnounce?(code)
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
