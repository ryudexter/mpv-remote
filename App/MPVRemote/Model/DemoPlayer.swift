import Foundation
import RemoteProtocol

/// A pretend mpv, so the app can be tried without a Mac — by someone curious,
/// or by App Review. It plays a made-up series and obeys every command.
final class DemoPlayer {
    var onChange: ((PlayerState) -> Void)?
    private(set) var state = PlayerState()
    /// When `state.position` was last set; playback carries on from there.
    private var anchoredAt = Date.now

    private struct Episode {
        var title: String
        var duration: Double
        var chapters: [String]
    }

    private static let episodes = [
        Episode(title: "Arrival", duration: 3130, chapters: ["Cold Open", "The Harbour", "Lights Out", "Departure"]),
        Episode(title: "The Northern Lights", duration: 2856, chapters: ["Cold Open", "Into the Dark", "Aurora Over the Fjord", "First Light"]),
        Episode(title: "Midnight Sun", duration: 2942, chapters: ["Cold Open", "The Long Day", "Across the Ice", "Sunset at Two"]),
        Episode(title: "Ice and Fire", duration: 3105, chapters: ["Cold Open", "The Volcano", "Meltwater", "Embers"]),
        Episode(title: "Homecoming", duration: 3320, chapters: ["Cold Open", "The Last Crossing", "Harbour Lights", "Home"]),
    ]

    init() {
        state.isRunning = true
        state.isIdle = false
        state.isPaused = false
        state.volume = 70
        state.tracks = [
            Track(kind: .video, number: 1, title: nil, language: nil, codec: "h264", isSelected: true, isExternal: false),
            Track(kind: .audio, number: 1, title: nil, language: "eng", codec: "aac", isSelected: true, isExternal: false),
            Track(kind: .audio, number: 2, title: "Director's Commentary", language: "eng", codec: "aac", isSelected: false, isExternal: false),
            Track(kind: .audio, number: 3, title: nil, language: "jpn", codec: "aac", isSelected: false, isExternal: false),
            Track(kind: .subtitle, number: 1, title: nil, language: "eng", codec: "subrip", isSelected: true, isExternal: false),
            Track(kind: .subtitle, number: 2, title: "SDH", language: "eng", codec: "subrip", isSelected: false, isExternal: false),
            Track(kind: .subtitle, number: 3, title: nil, language: "tur", codec: "subrip", isSelected: false, isExternal: false),
            Track(kind: .subtitle, number: 4, title: nil, language: "spa", codec: "subrip", isSelected: false, isExternal: false),
        ]
        load(episode: 1, at: 1385)

        // Moves the chapter along and rolls on to the next episode, as mpv would.
        Task { [weak self] in
            while true {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                self.tick()
            }
        }
    }

    func perform(_ command: PlayerCommand) {
        var position = currentPosition
        switch command {
        case .togglePause: state.isPaused.toggle()
        case .seek(let seconds): position = seconds
        case .skip(let seconds): position += seconds
        case .setVolume(let volume): state.volume = volume
        case .toggleMute: state.isMuted.toggle()
        case .setSpeed(let speed): state.speed = speed
        case .selectAudio(let id): select(id, kind: .audio)
        case .selectSubtitle(let id): select(id, kind: .subtitle)
        case .adjustSubtitleDelay(let seconds): state.subtitleDelay = ((state.subtitleDelay + seconds) * 10).rounded() / 10
        case .playlistNext: return load(episode: (state.playlistIndex ?? 0) + 1)
        case .playlistPrevious: return load(episode: (state.playlistIndex ?? 0) - 1)
        case .playlistPlay(let index): return load(episode: index)
        case .selectChapter(let index): position = state.chapters.first { $0.index == index }?.time ?? position
        case .toggleFullscreen: state.isFullscreen.toggle()
        }
        setPosition(position)
    }

    private var currentPosition: Double {
        let position = state.position ?? 0
        guard !state.isPaused else { return position }
        return min(position + Date.now.timeIntervalSince(anchoredAt) * state.speed, state.duration ?? position)
    }

    private func load(episode index: Int, at position: Double = 0) {
        guard Self.episodes.indices.contains(index) else { return }
        let episode = Self.episodes[index]
        let chapterLength = episode.duration / Double(episode.chapters.count)
        state.title = episode.title
        state.duration = episode.duration
        state.chapters = episode.chapters.enumerated().map { offset, title in
            Chapter(index: offset, title: title, time: (Double(offset) * chapterLength).rounded())
        }
        state.playlist = Self.episodes.enumerated().map { offset, episode in
            PlaylistEntry(index: offset, title: episode.title, isCurrent: offset == index)
        }
        state.playlistIndex = index
        setPosition(position)
    }

    private func setPosition(_ seconds: Double) {
        let position = min(max(0, seconds), state.duration ?? 0)
        state.position = position
        state.chapterIndex = state.chapters.last { $0.time <= position }?.index
        anchoredAt = .now
        onChange?(state)
    }

    private func select(_ id: Int?, kind: Track.Kind) {
        for index in state.tracks.indices where state.tracks[index].kind == kind {
            state.tracks[index].isSelected = state.tracks[index].number == id
        }
    }

    private func tick() {
        guard !state.isPaused, let duration = state.duration else { return }
        let position = currentPosition
        if position >= duration {
            let next = (state.playlistIndex ?? 0) + 1
            if Self.episodes.indices.contains(next) {
                load(episode: next)
            } else {
                state.isPaused = true
                setPosition(duration)
            }
        } else if state.chapters.last(where: { $0.time <= position })?.index != state.chapterIndex {
            setPosition(position)
        }
    }
}
