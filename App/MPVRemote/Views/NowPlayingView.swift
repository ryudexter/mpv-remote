import RemoteProtocol
import SwiftUI

struct NowPlayingView: View {
    @Environment(RemoteController.self) private var remote
    @State private var isShowingQueue = false

    private var state: PlayerState { remote.state }
    private var computerName: String { remote.computer?.name ?? "Computer" }

    var body: some View {
        NavigationStack {
            content
                // Fade between connecting, offline and playing rather than cut.
                .animation(.smooth(duration: 0.4), value: remote.status)
                .toolbar { toolbar }
                .navigationBarTitleDisplayMode(.inline)
                .background {
                    Backdrop(seed: state.isRunning ? state.title : nil)
                }
                .sheet(isPresented: $isShowingQueue) {
                    // See RootView: sheets on a Mac don't inherit it.
                    QueueView()
                        .environment(remote)
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch remote.status {
        case .unreachable:
            ContentUnavailableView {
                Label("Can't Reach \(computerName)", systemImage: "wifi.exclamationmark")
            } description: {
                Text("Open a video in mpv on \(computerName), and make sure your iPhone is on the same Wi-Fi. It reconnects by itself.")
            } actions: {
                Button("Try Again") { remote.connect() }
                    .buttonStyle(.glass)
            }
        case .connecting where !state.isRunning, .needsPairing:
            ConnectingView(computerName: computerName)
        default:
            if state.isRunning && !state.isIdle {
                player
                    .disabled(remote.status != .connected)
                    .opacity(remote.status == .connected ? 1 : 0.5)
            } else {
                ContentUnavailableView {
                    Label("Nothing Playing", systemImage: "play.slash")
                } description: {
                    Text(state.isRunning
                         ? "mpv is open on \(computerName), but nothing is loaded."
                         : "Open a video with mpv on \(computerName) and it will show up here.")
                }
            }
        }
    }

    private var player: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 8)
            Artwork(seed: state.title)
                .scaleEffect(state.isPaused ? 0.9 : 1)
                .animation(.spring(duration: 0.5, bounce: 0.3), value: state.isPaused)
            Spacer(minLength: 28)
            titles
            ScrubberView()
                .padding(.top, 20)
            TransportControls()
                .padding(.vertical, 28)
            VolumeControl()
            Spacer(minLength: 28)
            OptionsBar(isShowingQueue: $isShowingQueue)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 8)
    }

    private var titles: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(state.title ?? "Untitled")
                .font(.title2.weight(.bold))
                .lineLimit(2)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentTransition(.opacity)
        .animation(.smooth, value: state.title)
    }

    private var subtitle: String {
        if let chapter = state.currentChapter {
            return chapter.title ?? "Chapter \(chapter.index + 1)"
        }
        if state.playlist.count > 1, let index = state.playlistIndex {
            return "\(index + 1) of \(state.playlist.count)"
        }
        return " "
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Menu {
                if remote.isDemo {
                    Button("Exit Demo", systemImage: "xmark.circle") {
                        remote.forgetComputer()
                    }
                } else {
                    // Not "Forget": the pairing is kept, so coming back needs no code.
                    Button("Change Computer", systemImage: "arrow.left.arrow.right") {
                        remote.forgetComputer()
                    }
                }
            } label: {
                VStack(spacing: 0) {
                    Text(computerName)
                        .font(.subheadline.weight(.semibold))
                    Text(statusText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.primary)
            }
        }
        if state.isRunning && !state.isIdle {
            ToolbarItem(placement: .topBarTrailing) {
                Button(state.isFullscreen ? "Exit Full Screen" : "Full Screen",
                       systemImage: state.isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right") {
                    remote.send(.toggleFullscreen)
                }
            }
        }
    }

    private var statusText: String {
        if remote.isDemo { return "Demo · tap to exit" }
        return switch remote.status {
        case .connected: state.isRunning ? "mpv" : "mpv not running"
        case .connecting, .needsPairing: "Connecting…"
        case .unreachable: "Offline"
        }
    }
}

// MARK: - Artwork

/// mpv gives no cover art, so each title gets its own gradient instead, and
/// the same title always gets the same one.
struct Artwork: View {
    var seed: String?

    var body: some View {
        let palette = Palette(seed: seed)
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(LinearGradient(colors: [palette.light, palette.dark], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                Image(systemName: "film")
                    .font(.system(size: 52, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .aspectRatio(16 / 9, contentMode: .fit)
            .shadow(color: palette.dark.opacity(0.5), radius: 30, y: 14)
            .animation(.smooth(duration: 0.6), value: seed)
    }
}

/// Fills the screen behind the player with a dim wash of the artwork's colour.
struct Backdrop: View {
    var seed: String?

    var body: some View {
        let palette = Palette(seed: seed)
        LinearGradient(colors: [palette.dark.opacity(seed == nil ? 0 : 0.55), .black], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
            .animation(.smooth(duration: 0.6), value: seed)
    }
}

struct Palette {
    var light: Color
    var dark: Color

    init(seed: String?) {
        // Not hashValue: Swift seeds that differently on every launch.
        let hash = (seed ?? "").unicodeScalars.reduce(UInt32(5381)) { ($0 &* 33) &+ $1.value }
        let hue = Double(hash % 360) / 360
        light = Color(hue: hue, saturation: 0.55, brightness: 0.85)
        dark = Color(hue: (hue + 0.08).truncatingRemainder(dividingBy: 1), saturation: 0.75, brightness: 0.4)
    }
}
