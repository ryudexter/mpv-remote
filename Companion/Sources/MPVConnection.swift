import Foundation
import RemoteProtocol

/// Talks to mpv over its JSON IPC socket (`--input-ipc-server`). Keeps a
/// `PlayerState` current from property observations, turns `PlayerCommand`s
/// into mpv commands, and reconnects whenever mpv quits and comes back —
/// unless it was started by mpv itself, in which case it quits along with it.
@MainActor
final class MPVConnection {
    /// Called on every change. `positionOnly` is true when only `time-pos`
    /// moved, which during playback is many times a second.
    var onChange: ((PlayerState, _ positionOnly: Bool) -> Void)?
    /// Called with the name of each mpv event, such as "playback-restart".
    var onEvent: ((String) -> Void)?
    private(set) var state = PlayerState()

    private let socketPath: String
    private let exitsWithMPV: Bool
    private var socket: Int32 = -1
    private var readSource: DispatchSourceRead?
    private var buffer = Data()
    private var failedAttempts = 0
    /// Commands waiting for mpv's reply, by request id.
    private var pendingReplies: [Int: (Bool) -> Void] = [:]
    private var lastRequestID = 0

    private static let observedProperties = [
        "pause", "time-pos", "duration", "media-title", "volume", "volume-max", "mute",
        "speed", "sub-delay", "fullscreen", "track-list", "chapter-list", "chapter",
        "playlist", "playlist-pos", "idle-active",
    ]

    init(socketPath: String, exitsWithMPV: Bool) {
        self.socketPath = socketPath
        self.exitsWithMPV = exitsWithMPV
    }

    func start() {
        if socketPath.utf8.count > Self.maxSocketPathLength {
            // mpv can't create such a socket either, so this would wait for ever and say nothing.
            log("mpv's socket path is \(socketPath.utf8.count) bytes long, but a Unix socket's path can be at most \(Self.maxSocketPathLength), so mpv can't make it and this can't connect to it: \(socketPath). Use a shorter --input-ipc-server path.")
        }
        connect()
    }

    /// Shows a message on mpv's own screen for `seconds`.
    func showText(_ text: String, seconds: Int) {
        send(["show-text", text, seconds * 1000])
    }

    /// Saves the frame on screen, without subtitles or anything else drawn
    /// over it, then reports whether that worked. It doesn't while mpv's
    /// window is minimized, since mpv stops drawing it.
    func saveFrame(to url: URL, completion: @escaping (Bool) -> Void) {
        guard socket >= 0 else { return completion(false) }
        lastRequestID += 1
        pendingReplies[lastRequestID] = completion
        send(["screenshot-to-file", url.path, "video"], requestID: lastRequestID)
    }

    // MARK: Commands

    func perform(_ command: PlayerCommand) {
        switch command {
        case .togglePause: send(["cycle", "pause"])
        case .seek(let seconds): send(["seek", seconds, "absolute+exact"])
        case .skip(let seconds): send(["seek", seconds, "relative+exact"])
        case .setVolume(let volume): send(["set_property", "volume", volume])
        case .toggleMute: send(["cycle", "mute"])
        case .setSpeed(let speed): send(["set_property", "speed", speed])
        case .selectAudio(let id): send(["set_property", "aid", id.map { $0 as Any } ?? "no"])
        case .selectSubtitle(let id): send(["set_property", "sid", id.map { $0 as Any } ?? "no"])
        case .adjustSubtitleDelay(let seconds): send(["add", "sub-delay", seconds])
        case .playlistNext: send(["playlist-next"])
        case .playlistPrevious: send(["playlist-prev"])
        case .playlistPlay(let index): send(["set_property", "playlist-pos", index])
        case .selectChapter(let index): send(["set_property", "chapter", index])
        case .toggleFullscreen: send(["cycle", "fullscreen"])
        }
    }

    // MARK: Connection

    private func connect() {
        guard socket < 0 else { return }
        guard let socket = Self.openSocket(path: socketPath) else {
            failedAttempts += 1
            // Started by mpv, the socket should appear within moments. If it
            // never does, mpv is gone and there is nothing left to wait for.
            if exitsWithMPV && failedAttempts > 30 {
                log("mpv's socket never appeared at \(socketPath); quitting")
                exit(1)
            }
            retryLater()
            return
        }
        failedAttempts = 0
        self.socket = socket
        let source = DispatchSource.makeReadSource(fileDescriptor: socket, queue: .main)
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.readAvailable() }
        }
        source.setCancelHandler { close(socket) }
        source.resume()
        readSource = source

        for (index, name) in Self.observedProperties.enumerated() {
            send(["observe_property", index + 1, name])
        }
        state = PlayerState()
        state.isRunning = true
        log("Connected to mpv")
        onChange?(state, false)
    }

    private func disconnect() {
        readSource?.cancel()
        readSource = nil
        socket = -1
        buffer.removeAll()
        let unanswered = pendingReplies.values
        pendingReplies.removeAll()
        unanswered.forEach { $0(false) }
        if exitsWithMPV {
            log("mpv quit; quitting too")
            exit(0)
        }
        state = PlayerState()
        log("mpv went away; waiting for it to come back")
        onChange?(state, false)
        retryLater()
    }

    private func retryLater() {
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            self?.connect()
        }
    }

    private func send(_ command: [Any], requestID: Int? = nil) {
        var message: [String: Any] = ["command": command]
        if let requestID { message["request_id"] = requestID }
        guard socket >= 0,
              var data = try? JSONSerialization.data(withJSONObject: message)
        else { return }
        data.append(0x0A)
        data.withUnsafeBytes { bytes in
            var offset = 0
            while offset < bytes.count {
                let written = write(socket, bytes.baseAddress! + offset, bytes.count - offset)
                if written <= 0 { break }
                offset += written
            }
        }
    }

    // MARK: Reading

    private func readAvailable() {
        var chunk = [UInt8](repeating: 0, count: 64 * 1024)
        let count = read(socket, &chunk, chunk.count)
        if count < 0, errno == EAGAIN || errno == EINTR { return }
        guard count > 0 else {
            disconnect()
            return
        }
        buffer.append(contentsOf: chunk[0..<count])
        // mpv sends one JSON object per line.
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = buffer[buffer.startIndex..<newline]
            buffer.removeSubrange(buffer.startIndex...newline)
            handle(line: Data(line))
        }
    }

    private func handle(line: Data) {
        guard let message = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else { return }
        if message["event"] as? String == "property-change", let name = message["name"] as? String {
            apply(property: name, value: message["data"])
        } else if let event = message["event"] as? String {
            onEvent?(event)
        } else if let id = message["request_id"] as? Int, let completion = pendingReplies.removeValue(forKey: id) {
            completion(message["error"] as? String == "success")
        } else if let error = message["error"] as? String, error != "success" {
            log("mpv rejected a command: \(error)")
        }
    }

    private func apply(property name: String, value: Any?) {
        var new = state
        switch name {
        case "pause": new.isPaused = value as? Bool ?? false
        case "time-pos": new.position = value as? Double
        case "duration": new.duration = value as? Double
        case "media-title": new.title = value as? String
        case "volume": new.volume = value as? Double ?? new.volume
        case "volume-max": new.maxVolume = value as? Double ?? new.maxVolume
        case "mute": new.isMuted = value as? Bool ?? false
        case "speed": new.speed = value as? Double ?? 1
        case "sub-delay": new.subtitleDelay = value as? Double ?? 0
        case "fullscreen": new.isFullscreen = value as? Bool ?? false
        case "track-list": new.tracks = Self.tracks(from: value)
        case "chapter-list": new.chapters = Self.chapters(from: value)
        case "chapter": new.chapterIndex = (value as? Int).flatMap { $0 >= 0 ? $0 : nil }
        case "playlist": new.playlist = Self.playlist(from: value)
        case "playlist-pos": new.playlistIndex = (value as? Int).flatMap { $0 >= 0 ? $0 : nil }
        case "idle-active": new.isIdle = value as? Bool ?? false
        default: return
        }
        guard new != state else { return }
        state = new
        onChange?(state, name == "time-pos")
    }

    // MARK: Parsing mpv's lists

    private static func tracks(from value: Any?) -> [Track] {
        (value as? [[String: Any]] ?? []).compactMap { entry in
            let kind: Track.Kind
            switch entry["type"] as? String {
            case "video": kind = .video
            case "audio": kind = .audio
            case "sub": kind = .subtitle
            default: return nil
            }
            guard let id = entry["id"] as? Int else { return nil }
            return Track(
                kind: kind,
                number: id,
                title: entry["title"] as? String,
                language: entry["lang"] as? String,
                codec: entry["codec"] as? String,
                isSelected: entry["selected"] as? Bool ?? false,
                isExternal: entry["external"] as? Bool ?? false
            )
        }
    }

    private static func chapters(from value: Any?) -> [Chapter] {
        (value as? [[String: Any]] ?? []).enumerated().map { index, entry in
            Chapter(index: index, title: entry["title"] as? String, time: entry["time"] as? Double ?? 0)
        }
    }

    private static func playlist(from value: Any?) -> [PlaylistEntry] {
        (value as? [[String: Any]] ?? []).enumerated().map { index, entry in
            let filename = entry["filename"] as? String ?? ""
            let title = entry["title"] as? String
                ?? ((filename as NSString).lastPathComponent as NSString).deletingPathExtension
            return PlaylistEntry(index: index, title: title, isCurrent: entry["current"] as? Bool ?? false)
        }
    }

    // MARK: Socket

    /// What fits in `sockaddr_un.sun_path`, less the terminating zero.
    private static let maxSocketPathLength = MemoryLayout.size(ofValue: sockaddr_un().sun_path) - 1

    private static func openSocket(path: String) -> Int32? {
        let socket = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard socket >= 0 else { return nil }
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        let pathBytes = Array(path.utf8)
        guard pathBytes.count <= maxSocketPathLength else {
            close(socket)
            return nil
        }
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: pathBytes) }
        let result = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(socket, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard result == 0 else {
            close(socket)
            return nil
        }
        // A write after mpv quits must fail, not kill the companion with SIGPIPE.
        var on: Int32 = 1
        setsockopt(socket, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
        return socket
    }
}
