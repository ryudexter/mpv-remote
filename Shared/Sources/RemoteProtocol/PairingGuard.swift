import Foundation

/// Keeps pairing from being guessed or used to pester the person at the
/// computer. The code has only four digits, so wrong guesses are rationed:
///
/// - per source address, three wrong codes lock that address out for 30
///   seconds, then each further one doubles it, up to an hour;
/// - across all addresses, every `guessesPerCode` wrong codes change the code
///   and pause all guessing, for 15 seconds at first and up to 10 minutes if it
///   keeps happening, so a guesser who changes address still gets only a few
///   tries per pause;
/// - showing the code (a notification, a message over the video) is rationed
///   too, since any device on the network can ask for it.
///
/// A source is a string such as the phone's IP address; see `PairingGuard.source(of:)`.
public struct PairingGuard: Sendable {
    public let guessesPerCode: Int
    private var sources: [String: Backoff] = [:]
    private var pause: Backoff
    private var announcements: Backoff
    private var wrongGuesses = 0

    /// How many addresses are remembered at most; the stalest go first.
    static let maxSources = 256

    public init(guessesPerCode: Int = 5) {
        self.guessesPerCode = guessesPerCode
        pause = Self.newPause()
        announcements = Self.newAnnouncements()
    }

    private static func newSource() -> Backoff { Backoff(allowance: 2, base: 30, cap: 3600, forgetAfter: 6 * 3600) }
    private static func newPause() -> Backoff { Backoff(base: 15, cap: 600) }
    private static func newAnnouncements() -> Backoff { Backoff(allowance: 1, base: 15, cap: 600) }

    /// Whether a code from `source` may be checked at all right now.
    public func allowsGuess(from source: String, at now: Date) -> Bool {
        !pause.isBlocked(at: now) && !(sources[source]?.isBlocked(at: now) ?? false)
    }

    /// Notes a wrong code. Returns true when the code has been guessed at too
    /// often and must be changed.
    public mutating func recordWrongGuess(from source: String, at now: Date) -> Bool {
        var backoff = sources[source] ?? Self.newSource()
        backoff.strike(at: now)
        sources[source] = backoff
        forgetStaleSources(at: now)

        wrongGuesses += 1
        guard wrongGuesses >= guessesPerCode else { return false }
        wrongGuesses = 0
        pause.strike(at: now)
        return true
    }

    /// A phone paired for real: whoever it was isn't guessing.
    public mutating func recordPairing(from source: String) {
        sources[source] = nil
        wrongGuesses = 0
        pause = Self.newPause()
        announcements = Self.newAnnouncements()
    }

    /// Whether the code may be shown now for a phone at `source`. A yes uses up
    /// one of the allowed showings; each one that nobody answers by pairing
    /// makes the wait for the next one longer.
    public mutating func allowsAnnouncement(for source: String?, at now: Date) -> Bool {
        if let source, sources[source]?.isBlocked(at: now) == true { return false }
        guard !announcements.isBlocked(at: now) else { return false }
        announcements.strike(at: now)
        return true
    }

    private mutating func forgetStaleSources(at now: Date) {
        guard sources.count > Self.maxSources else { return }
        sources = sources.filter { !$0.value.isForgotten(at: now) }
        if sources.count > Self.maxSources {
            // Everything is recent: a flood from many addresses. Start over, as
            // the global pause still limits guessing across all of them.
            sources.removeAll()
        }
    }

    /// The part of an address that identifies who is asking. An IPv4 address is
    /// used whole. An IPv6 one is cut to its /64 network, since a device can
    /// take any address within it and would otherwise get a fresh allowance
    /// for each. `bytes` is the raw address, 4 or 16 bytes.
    public static func source(of bytes: [UInt8]) -> String {
        switch bytes.count {
        case 4:
            return bytes.map(String.init).joined(separator: ".")
        case 16:
            return bytes[..<8].map { String(format: "%02x", $0) }.joined() + "::/64"
        default:
            return "unknown"
        }
    }
}
