import Foundation

/// Between the Apple Watch app and the iPhone app, over WatchConnectivity.
///
/// watchOS keeps apps from opening the WebSocket the companion speaks, so the
/// Watch sends its commands to the iPhone, which forwards them over its own
/// connection. WatchConnectivity wakes the iPhone app in the background for them.
public enum WatchMessage: Codable, Sendable {
    /// Watch → iPhone: a command for mpv, forwarded as if sent from the iPhone.
    case command(PlayerCommand)
    /// Watch → iPhone: send the state back, and connect to the computer now,
    /// ready for the first command. Sent when the Watch app opens and every 15
    /// seconds while it's open, which keeps the iPhone app awake.
    case requestState
    /// iPhone → Watch: what the Watch should show.
    case state(WatchState)

    private static let payloadKey = "mpvremote.watch"

    /// Encodes the message for `WCSession.sendMessage(_:replyHandler:)`.
    public func watchConnectivityMessage() throws -> [String: Any] {
        [Self.payloadKey: try JSONEncoder().encode(self)]
    }

    public init?(watchConnectivityMessage message: [String: Any]) {
        guard let data = message[Self.payloadKey] as? Data,
              let decoded = try? JSONDecoder().decode(WatchMessage.self, from: data)
        else { return nil }
        self = decoded
    }
}

public struct WatchState: Codable, Sendable, Equatable {
    public enum Connection: String, Codable, Sendable {
        /// No computer has been chosen on the iPhone yet.
        case noComputer
        case connecting
        /// The computer wants its code, which is entered on the iPhone.
        case needsPairing
        case connected
        case unreachable
    }

    public var computerName: String?
    public var connection: Connection
    /// The player, without its playlist and chapters, which can outgrow a
    /// WatchConnectivity message.
    public var player: PlayerState
    public var playlistCount: Int
    /// When `player.position` was right. The Watch carries on from there, as
    /// the iPhone does between updates.
    public var positionDate: Date

    public init(computerName: String?, connection: Connection, player: PlayerState, playlistCount: Int, positionDate: Date) {
        self.computerName = computerName
        self.connection = connection
        self.player = player
        self.playlistCount = playlistCount
        self.positionDate = positionDate
    }

    /// Where playback is at `date`, assuming it carried on since `positionDate`.
    public func position(at date: Date) -> Double {
        guard let position = player.position else { return 0 }
        guard !player.isPaused else { return position }
        let extrapolated = position + date.timeIntervalSince(positionDate) * player.speed
        return min(extrapolated, player.duration ?? extrapolated)
    }
}
