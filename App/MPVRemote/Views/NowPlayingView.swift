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
            Artwork(seed: state.title, frame: remote.thumbnail)
                .overlay { DoubleTapToSkip() }
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
    /// The frame mpv is showing, which replaces the gradient when there is one.
    var frame: UIImage?

    var body: some View {
        let palette = Palette(seed: seed)
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(LinearGradient(colors: [palette.light, palette.dark], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                if let frame {
                    Image(uiImage: frame)
                        .resizable()
                        .scaledToFill()
                        // A new identity for each frame, so they crossfade.
                        .id(ObjectIdentifier(frame))
                        .transition(.opacity)
                } else {
                    Image(systemName: "film")
                        .font(.system(size: 52, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .clipShape(.rect(cornerRadius: 26, style: .continuous))
            .aspectRatio(16 / 9, contentMode: .fit)
            .shadow(color: palette.dark.opacity(0.5), radius: 30, y: 14)
            .animation(.smooth(duration: 0.6), value: seed)
            .animation(.smooth(duration: 0.6), value: frame)
    }
}

/// Double-tapping the left or right half of the picture skips back or forward
/// 10 seconds, as in video apps. Double-tapping again soon after adds another
/// 10, and a badge on that side counts up how far it has gone.
struct DoubleTapToSkip: View {
    private static let step = 10.0

    @Environment(RemoteController.self) private var remote
    /// How far the double-taps in a row have skipped, negative going back.
    /// Nil once the badge has faded.
    @State private var total: Double?
    @State private var taps = 0
    @State private var fade: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 0) {
            side(direction: -1)
            side(direction: 1)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: taps)
        // The buttons below do the same for VoiceOver, where a double-tap activates.
        .accessibilityHidden(true)
    }

    private func side(direction: Double) -> some View {
        Color.clear
            .contentShape(.rect)
            .overlay {
                if let total, total.sign == direction.sign {
                    badge(total)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .onTapGesture(count: 2) { skip(by: direction * Self.step) }
    }

    private func badge(_ seconds: Double) -> some View {
        HStack(spacing: 6) {
            if seconds < 0 { Image(systemName: "backward.fill") }
            Text("\(Int(abs(seconds))) s")
                .contentTransition(.numericText(value: seconds))
            if seconds > 0 { Image(systemName: "forward.fill") }
        }
        .font(.subheadline.weight(.semibold).monospacedDigit())
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .capsule)
    }

    private func skip(by seconds: Double) {
        taps += 1
        remote.send(.skip(by: seconds))
        withAnimation(.snappy) {
            // Turning round starts the count again.
            if let total, total.sign == seconds.sign {
                self.total = total + seconds
            } else {
                total = seconds
            }
        }
        fade?.cancel()
        fade = Task {
            try? await Task.sleep(for: .seconds(0.9))
            guard !Task.isCancelled else { return }
            withAnimation(.smooth) { total = nil }
        }
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
