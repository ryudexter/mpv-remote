import Foundation

/// A snapshot of the player, rebuilt by the companion from mpv's property
/// observations and pushed to the phone whenever something changes.
public struct PlayerState: Codable, Sendable, Equatable {
    /// False while mpv isn't running, or its IPC socket can't be reached.
    public var isRunning = false
    /// mpv is running but has nothing loaded.
    public var isIdle = true
    public var title: String?
    public var duration: Double?
    /// Seconds into the file when this snapshot was taken. While playing, the
    /// phone extrapolates from here rather than waiting for the next update.
    public var position: Double?
    public var isPaused = true
    public var volume: Double = 100
    public var maxVolume: Double = 130
    public var isMuted = false
    public var speed: Double = 1
    public var subtitleDelay: Double = 0
    public var isFullscreen = false
    public var tracks: [Track] = []
    public var chapters: [Chapter] = []
    public var chapterIndex: Int?
    public var playlist: [PlaylistEntry] = []
    public var playlistIndex: Int?

    public init() {}
}

public struct Track: Codable, Sendable, Equatable, Identifiable {
    public enum Kind: String, Codable, Sendable {
        case video, audio, subtitle
    }

    public var kind: Kind
    /// mpv's id for the track. Ids are only unique within one kind.
    public var number: Int
    public var title: String?
    /// Usually an ISO 639 code such as "eng" or "jpn".
    public var language: String?
    public var codec: String?
    public var isSelected: Bool
    public var isExternal: Bool

    public var id: String { "\(kind.rawValue)-\(number)" }

    public init(kind: Kind, number: Int, title: String?, language: String?, codec: String?, isSelected: Bool, isExternal: Bool) {
        self.kind = kind
        self.number = number
        self.title = title
        self.language = language
        self.codec = codec
        self.isSelected = isSelected
        self.isExternal = isExternal
    }
}

public struct Chapter: Codable, Sendable, Equatable, Identifiable {
    public var index: Int
    public var title: String?
    public var time: Double

    public var id: Int { index }

    public init(index: Int, title: String?, time: Double) {
        self.index = index
        self.title = title
        self.time = time
    }
}

public struct PlaylistEntry: Codable, Sendable, Equatable, Identifiable {
    public var index: Int
    public var title: String
    public var isCurrent: Bool

    public var id: Int { index }

    public init(index: Int, title: String, isCurrent: Bool) {
        self.index = index
        self.title = title
        self.isCurrent = isCurrent
    }
}
