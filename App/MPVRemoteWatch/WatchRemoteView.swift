import RemoteProtocol
import SwiftUI

/// One screen, as in Cingle Remote's Watch app: a pad to tap and swipe on, with
/// Previous, Play/Pause and Next along its bottom, under the computer's name.
/// Tap the pad to play or pause, swipe sideways to skip 10 seconds, and up or
/// down for volume; the Digital Crown changes volume too. The button in the
/// top-left corner has the rest: full screen, mute, subtitles and audio.
struct WatchRemoteView: View {
    @Environment(RemoteLink.self) private var link
    @Environment(\.scenePhase) private var scenePhase
    @State private var crown = 0.0
    @State private var lastCrownStep = 0
    @State private var showingOptions = false
    @AppStorage("hasSeenGestureTips") private var hasSeenTips = false

    /// The crown wraps around at the ends of this, which `Crown` accounts for.
    private static let crownRange = -1_000.0...1_000.0

    var body: some View {
        Pad()
            .navigationTitle(link.state?.computerName ?? "MPV Remote")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingOptions = true
                    } label: {
                        // White: in the tint, it disappears into the purple button.
                        Image(systemName: "ellipsis")
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel("Options")
                }
            }
            .navigationDestination(isPresented: $showingOptions) {
                PlayerOptions()
            }
            .sheet(isPresented: Binding { !hasSeenTips } set: { hasSeenTips = !$0 }) {
                GestureTips()
            }
            .focusable()
            .digitalCrownRotation(
                $crown, from: Self.crownRange.lowerBound, through: Self.crownRange.upperBound, by: 1,
                sensitivity: .low, isContinuous: true, isHapticFeedbackEnabled: true
            )
            .onChange(of: crown) { _, value in
                // One volume step per crown detent.
                let step = Int(value.rounded())
                let span = Int(Self.crownRange.upperBound - Self.crownRange.lowerBound) + 1
                guard let up = Crown.isTurningUp(from: lastCrownStep, to: step, span: span) else { return }
                link.changeVolume(up: up)
                lastCrownStep = step
            }
            .onChange(of: scenePhase, initial: true) { _, phase in
                if phase == .active {
                    link.appDidBecomeActive()
                } else {
                    link.appDidResignActive()
                }
            }
            .overlay(alignment: .bottom) {
                if let message = link.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .padding(8)
                        .background(.red.opacity(0.85), in: .rect(cornerRadius: 10))
                        .onTapGesture { link.errorMessage = nil }
                }
            }
    }
}

/// The touch area, tinted towards the bottom, with what's playing along its top
/// and the three keys sitting on its lower edge. The space around the keys is
/// part of the touch area too.
private struct Pad: View {
    @Environment(RemoteLink.self) private var link

    private let cornerRadius: CGFloat = 22
    /// The strip along the bottom that the keys sit in, left out of the arrows above.
    private let keyStrip: CGFloat = 54

    var body: some View {
        let player = link.state?.player
        SwipeArea(keyStrip: keyStrip)
            .disabled(!link.isPlaying)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(LinearGradient(
                        colors: [.white.opacity(0.06), Color.remotePurple.opacity(0.55)],
                        startPoint: .top, endPoint: .bottom))
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .contentShape(.rect(cornerRadius: cornerRadius))
            .clipShape(.rect(cornerRadius: cornerRadius))
            .overlay(alignment: .top) {
                if link.isPlaying {
                    NowPlaying()
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .allowsHitTesting(false)
                }
            }
            .overlay {
                if !link.isPlaying {
                    Hint()
                        .padding(8)
                        .padding(.bottom, keyStrip)
                        .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .bottom) {
                HStack(spacing: 0) {
                    RoundKey("Previous", systemImage: "backward.end.fill", command: .playlistPrevious, diameter: 36)
                        .disabled((link.state?.playlistCount ?? 0) < 2)
                    Spacer(minLength: 0)
                    // Large, as it's the key that gets used most. With nothing to
                    // play, the hint needs the room.
                    RoundKey(player?.isPaused != false ? "Play" : "Pause",
                             systemImage: player?.isPaused != false ? "play.fill" : "pause.fill",
                             command: .togglePause, diameter: link.isPlaying ? 64 : 46)
                    Spacer(minLength: 0)
                    RoundKey("Next", systemImage: "forward.end.fill", command: .playlistNext, diameter: 36)
                        .disabled((link.state?.playlistCount ?? 0) < 2)
                }
                // 10 points between the keys, closing up on the narrowest Watches.
                .frame(maxWidth: 156)
                .padding(.horizontal, 4)
                .disabled(!link.isPlaying)
                .padding(.bottom, 4)
            }
    }
}

/// The title, and how far into it mpv is.
private struct NowPlaying: View {
    @Environment(RemoteLink.self) private var link

    var body: some View {
        let player = link.state?.player
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let duration = max(player?.duration ?? 0, 0.001)
            let position = link.position(at: context.date)
            VStack(spacing: 4) {
                Text(player?.title ?? "Untitled")
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.2))
                        Capsule().fill(.white)
                            .frame(width: geometry.size.width * min(max(position / duration, 0), 1))
                    }
                }
                .frame(height: 3)
                HStack {
                    Text(formatTime(position))
                    Spacer()
                    Text("-" + formatTime(duration - position))
                }
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// What the pad says while there's nothing to control.
private struct Hint: View {
    @Environment(RemoteLink.self) private var link

    var body: some View {
        if let state = link.state {
            let name = state.computerName ?? ""
            VStack(spacing: 4) {
                switch state.connection {
                case .noComputer:
                    Image(systemName: "iphone").font(.title3)
                    Text("Choose your computer in MPV Remote on your iPhone.")
                case .needsPairing:
                    Image(systemName: "iphone").font(.title3)
                    Text("Open MPV Remote on your iPhone to pair with \(name).")
                case .connecting:
                    ProgressView().frame(height: 24)
                    Text("Connecting to \(name)…")
                case .unreachable:
                    Image(systemName: "wifi.exclamationmark").font(.title3)
                    Text("Can't reach \(name). Open a video in mpv on it.")
                case .connected:
                    Image(systemName: "play.slash").font(.title3)
                    Text(state.player.isRunning
                         ? "mpv is open on \(name), but nothing is loaded."
                         : "Open a video with mpv on \(name).")
                }
            }
            .font(.footnote)
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
        } else {
            // Until the iPhone has answered.
            ProgressView()
        }
    }
}

/// Tap anywhere to play or pause, swipe sideways to skip 10 seconds and up or
/// down for volume. A finger that keeps dragging keeps going, one step per
/// stretch of travel, so one long drag skips a minute.
private struct SwipeArea: View {
    @Environment(RemoteLink.self) private var link
    let keyStrip: CGFloat

    @State private var touch: CGPoint?
    /// Where the finger landed, or where it was when the last step was sent.
    @State private var anchor: CGPoint?
    @State private var didMove = false
    @State private var touchStarted: Date?
    @State private var presses = 0

    /// How far a finger must travel before a touch counts as a swipe rather than a tap.
    private let swipeThreshold: CGFloat = 16
    /// Further travel for each extra step while the finger keeps dragging.
    private let stepDistance: CGFloat = 36
    /// A touch that stays put for longer than this is a hand resting on the
    /// pad or a press-and-hold, not a tap, and doesn't pause.
    private let tapDuration: TimeInterval = 0.5

    var body: some View {
        Arrows()
            .padding(.bottom, keyStrip)
            .overlay {
                // Shows where the finger is, so a tap or swipe visibly lands.
                if let touch {
                    Circle()
                        .fill(.white.opacity(0.12))
                        .frame(width: 48, height: 48)
                        .position(touch)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if touchStarted == nil { touchStarted = value.time }
                        touch = value.location
                        step(to: value.location, from: value.startLocation)
                    }
                    .onEnded { value in
                        // A quick flick can end before any change crossed the threshold.
                        step(to: value.location, from: value.startLocation)
                        let duration = value.time.timeIntervalSince(touchStarted ?? value.time)
                        if !didMove, duration <= tapDuration { send(.togglePause) }
                        touchStarted = nil
                        touch = nil
                        anchor = nil
                        didMove = false
                    }
            )
            .sensoryFeedback(.selection, trigger: presses)
            .accessibilityRepresentation { PadButtons() }
    }

    /// Sends a step once the finger has travelled far enough from the last one,
    /// in whichever axis it moved most.
    private func step(to location: CGPoint, from start: CGPoint) {
        let anchor = anchor ?? start
        self.anchor = anchor
        let dx = location.x - anchor.x
        let dy = location.y - anchor.y
        guard max(abs(dx), abs(dy)) >= (didMove ? stepDistance : swipeThreshold) else { return }

        if abs(dx) > abs(dy) {
            send(.skip(by: dx > 0 ? 10 : -10))
        } else {
            presses += 1
            link.changeVolume(up: dy < 0)
        }
        self.anchor = location
        didMove = true
    }

    private func send(_ command: PlayerCommand) {
        presses += 1
        link.send(command)
    }
}

/// What the pad and the crown do, which nothing on it spells out. Shown the
/// first time the app opens.
private struct GestureTips: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                tip("Tap to play or pause", systemImage: "hand.tap.fill")
                tip("Swipe sideways to skip 10 seconds", systemImage: "hand.draw.fill")
                tip("Turn the Digital Crown for volume", systemImage: "digitalcrown.arrow.clockwise.fill")
                Button("Got It") { dismiss() }
                    .padding(.top, 4)
            }
            .padding(.horizontal, 4)
        }
    }

    private func tip(_ title: LocalizedStringKey, systemImage: String) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.tint)
                // The symbols differ in width; this keeps the text lined up.
                .frame(width: 22)
        }
        .font(.footnote)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Faint skip marks at the pad's sides, so it reads as something to swipe on.
private struct Arrows: View {
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        ZStack {
            mark("gobackward.10").frame(maxWidth: .infinity, alignment: .leading)
            mark("goforward.10").frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        // Below what's playing, which takes the top of the pad.
        .padding(.top, 36)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(isEnabled ? 1 : 0)
        .allowsHitTesting(false)
    }

    private func mark(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.footnote.weight(.bold))
            .foregroundStyle(.white.opacity(0.3))
    }
}

/// What VoiceOver gets instead of a gesture surface: plain buttons.
private struct PadButtons: View {
    @Environment(RemoteLink.self) private var link

    var body: some View {
        VStack {
            Button("Louder") { link.changeVolume(up: true) }
            HStack {
                Button("Back 10 Seconds") { link.send(.skip(by: -10)) }
                Button(link.state?.player.isPaused != false ? "Play" : "Pause") { link.send(.togglePause) }
                Button("Forward 10 Seconds") { link.send(.skip(by: 10)) }
            }
            Button("Quieter") { link.changeVolume(up: false) }
        }
    }
}

/// A round key on the pad's bottom edge, which gives a little when pressed.
private struct RoundKey: View {
    @Environment(RemoteLink.self) private var link
    @Environment(\.isEnabled) private var isEnabled
    let title: LocalizedStringKey
    let systemImage: String
    let command: PlayerCommand
    let diameter: CGFloat
    @State private var presses = 0

    init(_ title: LocalizedStringKey, systemImage: String, command: PlayerCommand, diameter: CGFloat) {
        self.title = title
        self.systemImage = systemImage
        self.command = command
        self.diameter = diameter
    }

    var body: some View {
        Button {
            presses += 1
            link.send(command)
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: diameter * 0.4, weight: .semibold))
                .foregroundStyle(.white.opacity(isEnabled ? 1 : 0.35))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: diameter, height: diameter)
                .background(Circle().fill(Color(white: 0.16)))
                .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
        }
        .buttonStyle(PressStyle())
        .sensoryFeedback(.selection, trigger: presses)
        .accessibilityLabel(title)
    }
}

private struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
    }
}

/// Full screen and mute, then the subtitles and audio to choose from.
private struct PlayerOptions: View {
    @Environment(RemoteLink.self) private var link

    var body: some View {
        let player = link.state?.player ?? PlayerState()
        List {
            if link.isPlaying {
                Button {
                    link.send(.toggleFullscreen)
                } label: {
                    label(player.isFullscreen ? "Exit Full Screen" : "Full Screen",
                          systemImage: player.isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                }
                Button {
                    link.send(.toggleMute)
                } label: {
                    label(player.isMuted ? "Unmute" : "Mute",
                          systemImage: player.isMuted ? "speaker.slash.fill" : "speaker.fill")
                }
                if !player.subtitleTracks.isEmpty {
                    Section("Subtitles") {
                        row("Off", isSelected: !player.subtitleTracks.contains(where: \.isSelected)) {
                            link.send(.selectSubtitle(nil))
                        }
                        ForEach(player.subtitleTracks) { track in
                            row(track.displayName, isSelected: track.isSelected) {
                                link.send(.selectSubtitle(track.number))
                            }
                        }
                    }
                }
                if player.audioTracks.count > 1 {
                    Section("Audio") {
                        ForEach(player.audioTracks) { track in
                            row(track.displayName, isSelected: track.isSelected) {
                                link.send(.selectAudio(track.number))
                            }
                        }
                    }
                }
            }
            Section {
            } footer: {
                Text("To use another computer, choose it in MPV Remote on your iPhone.")
            }
        }
        .navigationTitle("Options")
    }

    private func label(_ title: LocalizedStringKey, systemImage: String) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.tint)
        }
    }

    private func row(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
