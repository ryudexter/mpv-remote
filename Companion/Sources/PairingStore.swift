import Foundation
import RemoteProtocol

/// Decides which phones may control mpv. A phone proves itself once with the
/// 4-digit code printed by the companion and gets a long random token back,
/// which it presents on every later connection.
@MainActor
final class PairingStore {
    enum Outcome {
        case paired(token: String)
        case wrongCode
        /// Not even checked: this phone, or everyone, has guessed too often lately.
        case lockedOut
    }

    private struct Device: Codable {
        var name: String
        var token: String
        var pairedAt: Date
    }

    private(set) var code = PairingStore.makeCode()
    private var devices: [Device]
    private var guesses = PairingGuard()
    private var announced: (code: String, at: Date)?
    private var lastLockoutLogged = Date.distantPast
    private let fileURL: URL

    init(fileURL: URL = URL.applicationSupportDirectory.appending(path: "MPV Remote/paired-devices.json")) {
        self.fileURL = fileURL
        devices = Self.load(from: fileURL)
    }

    /// Picks up phones another companion paired since this one started.
    func reload() {
        devices = Self.load(from: fileURL)
    }

    private static func load(from url: URL) -> [Device] {
        (try? JSONDecoder().decode([Device].self, from: Data(contentsOf: url))) ?? []
    }

    func deviceName(forToken token: String) -> String? {
        devices.first { $0.token == token }?.name
    }

    /// Checks `attempt` against the current code and, if it matches, returns a
    /// new token. `source` says who is asking (see `PairingGuard.source(of:)`).
    func pair(code attempt: String, deviceName: String, from source: String) -> Outcome {
        let now = Date.now
        guard guesses.allowsGuess(from: source, at: now) else {
            // One line per burst, so a flood of guesses can't fill the log.
            if now.timeIntervalSince(lastLockoutLogged) > 10 {
                log("Ignoring a pairing code from \(source): too many wrong ones lately")
                lastLockoutLogged = now
            }
            return .lockedOut
        }
        guard attempt == code else {
            // Four digits are only 10,000 guesses; don't let anyone make many of them.
            if guesses.recordWrongGuess(from: source, at: now) {
                rotateCode()
                announceCode(reason: "Too many wrong pairing codes.", to: source)
            }
            return .wrongCode
        }
        let token = (0..<32).map { _ in String(format: "%02x", UInt8.random(in: .min ... .max)) }.joined()
        devices.append(Device(name: deviceName, token: token, pairedAt: .now))
        save()
        guesses.recordPairing(from: source)
        rotateCode()
        return .paired(token: token)
    }

    /// Called with each code worth showing someone, e.g. on mpv's own screen.
    var onAnnounce: ((String) -> Void)?

    /// Logs the code and shows it as a notification, since the companion
    /// usually runs in the background with no terminal anyone is looking at.
    /// Anyone on the network can ask for this, so it isn't done every time:
    /// not again for the same code within a minute, and less and less often
    /// while nobody pairs (see `PairingGuard`). `source` is who asked.
    func announceCode(reason: String, to source: String?) {
        // A phone that reconnects while still unpaired shouldn't bring up the same code again.
        if let announced, announced.code == code, Date.now.timeIntervalSince(announced.at) < 60 { return }
        guard guesses.allowsAnnouncement(for: source, at: .now) else { return }
        log("\(reason) Pairing code: \(code)")
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
