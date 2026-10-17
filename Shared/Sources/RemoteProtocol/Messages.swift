import Foundation

public enum RemoteService {
    /// Bonjour type the companion advertises and the app browses for.
    public static let bonjourType = "_mpvremote._tcp"
    public static let defaultPort: UInt16 = 7655
    /// Bumped whenever a message changes shape.
    public static let protocolVersion = 1
}

/// Phone → computer. Every message is one WebSocket text frame of JSON.
public enum ClientMessage: Codable, Sendable {
    /// First message on every connection. `token` is nil until this phone has paired.
    case hello(version: Int, token: String?)
    /// Answers `pairingRequired` with the code the companion printed.
    case pair(code: String, deviceName: String)
    /// Only honoured once the connection has been authorised.
    case command(PlayerCommand)
}

/// Computer → phone.
public enum ServerMessage: Codable, Sendable {
    /// The token was accepted; `state` messages follow.
    case welcome(computerName: String)
    /// No token, or one the companion no longer knows.
    case pairingRequired(computerName: String)
    /// Pairing succeeded. The phone keeps this and sends it in every `hello`.
    case paired(token: String)
    case pairingFailed
    case state(PlayerState)
    /// A small JPEG of the frame mpv is showing, or nil once there's none to
    /// show. Companions from before this never send it, and apps from before
    /// it fail to decode it and skip it, so neither needs the other updated.
    case thumbnail(jpeg: Data?)
}

/// Everything the phone may ask mpv to do. The companion maps each case to a
/// fixed mpv command, so nothing the phone sends ever reaches mpv verbatim —
/// mpv's IPC can also run programs, and that must stay unreachable from the network.
public enum PlayerCommand: Codable, Sendable, Equatable {
    case togglePause
    /// Absolute position in seconds.
    case seek(to: Double)
    /// Relative jump in seconds; negative goes back.
    case skip(by: Double)
    case setVolume(Double)
    case toggleMute
    case setSpeed(Double)
    /// mpv track id, or nil to turn the track off.
    case selectAudio(Int?)
    case selectSubtitle(Int?)
    case adjustSubtitleDelay(by: Double)
    case playlistNext
    case playlistPrevious
    case playlistPlay(index: Int)
    case selectChapter(Int)
    case toggleFullscreen
}
