import RemoteProtocol
import SwiftUI

/// The progress bar. It thickens under your finger, like the system's own players.
struct ScrubberView: View {
    @Environment(RemoteController.self) private var remote
    @State private var dragPosition: Double?

    var body: some View {
        let duration = max(remote.state.duration ?? 0, 0.001)
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let position = dragPosition ?? remote.position(at: context.date)
            VStack(spacing: 6) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.2))
                        Capsule().fill(.white)
                            .frame(width: geometry.size.width * min(max(position / duration, 0), 1))
                    }
                    .frame(height: dragPosition == nil ? 6 : 12)
                    .frame(maxHeight: .infinity)
                    .contentShape(.rect)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                dragPosition = min(max(value.location.x / geometry.size.width, 0), 1) * duration
                            }
                            .onEnded { _ in
                                if let dragPosition { remote.send(.seek(to: dragPosition)) }
                                dragPosition = nil
                            }
                    )
                }
                .frame(height: 24)

                HStack {
                    Text(formatTime(position))
                    Spacer()
                    Text("-" + formatTime(duration - position))
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(dragPosition == nil ? .secondary : .primary)
            }
            .accessibilityElement()
            .accessibilityLabel("Playback position")
            .accessibilityValue("\(formatTime(position)) of \(formatTime(duration))")
            .accessibilityAdjustableAction { direction in
                remote.send(.skip(by: direction == .increment ? 10 : -10))
            }
        }
        .animation(.spring(duration: 0.25), value: dragPosition == nil)
    }
}

struct TransportControls: View {
    @Environment(RemoteController.self) private var remote
    @State private var taps = 0

    var body: some View {
        let state = remote.state
        let hasPlaylist = state.playlist.count > 1
        HStack {
            button("Previous", systemImage: "backward.end.fill", size: 22, command: .playlistPrevious)
                .disabled(!hasPlaylist)
            Spacer()
            button("Back 10 Seconds", systemImage: "gobackward.10", size: 30, command: .skip(by: -10))
            Spacer()
            Button {
                taps += 1
                remote.send(.togglePause)
            } label: {
                Image(systemName: state.isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 38))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 84, height: 84)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .accessibilityLabel(state.isPaused ? "Play" : "Pause")
            Spacer()
            button("Forward 30 Seconds", systemImage: "goforward.30", size: 30, command: .skip(by: 30))
            Spacer()
            button("Next", systemImage: "forward.end.fill", size: 22, command: .playlistNext)
                .disabled(!hasPlaylist)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .sensoryFeedback(.impact(weight: .light), trigger: taps)
    }

    private func button(_ title: String, systemImage: String, size: CGFloat, command: PlayerCommand) -> some View {
        Button {
            taps += 1
            remote.send(command)
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: size, weight: .medium))
                .frame(width: 48, height: 48)
                .contentShape(.rect)
        }
        .accessibilityLabel(title)
    }
}

struct VolumeControl: View {
    @Environment(RemoteController.self) private var remote
    /// While the slider is held, it shows this rather than what mpv reports,
    /// so echoes of earlier values can't make it jump under your finger.
    @State private var draft: Double?

    var body: some View {
        let state = remote.state
        HStack(spacing: 14) {
            Button {
                remote.send(.toggleMute)
            } label: {
                Image(systemName: state.isMuted ? "speaker.slash.fill" : "speaker.fill")
                    .frame(width: 24)
                    .contentTransition(.symbolEffect(.replace))
            }
            .accessibilityLabel(state.isMuted ? "Unmute" : "Mute")

            Slider(
                value: Binding(
                    get: { draft ?? state.volume },
                    set: { value in
                        let rounded = value.rounded()
                        if rounded != draft {
                            draft = rounded
                            remote.send(.setVolume(rounded))
                        }
                    }
                ),
                in: 0...max(state.maxVolume, 100)
            ) { isEditing in
                if !isEditing { draft = nil }
            }
            .tint(.white)
            .accessibilityLabel("Volume")

            Image(systemName: "speaker.wave.3.fill")
                .frame(width: 24)
                .accessibilityHidden(true)
        }
        .buttonStyle(.plain)
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
}

/// Subtitles, audio, speed and the queue, in one row of glass buttons.
struct OptionsBar: View {
    @Environment(RemoteController.self) private var remote
    @Binding var isShowingQueue: Bool

    var body: some View {
        let state = remote.state
        GlassEffectContainer {
            HStack(spacing: 18) {
                subtitlesMenu(state)
                audioMenu(state)
                speedMenu(state)
                Button {
                    isShowingQueue = true
                } label: {
                    optionLabel("Queue", systemImage: "list.bullet")
                }
                .disabled(state.playlist.count < 2 && state.chapters.isEmpty)
            }
        }
        .buttonStyle(.plain)
    }

    private func subtitlesMenu(_ state: PlayerState) -> some View {
        Menu {
            Picker("Subtitles", selection: Binding(
                get: { state.subtitleTracks.first(where: \.isSelected)?.number },
                set: { remote.send(.selectSubtitle($0)) }
            )) {
                Text("Off").tag(Int?.none)
                ForEach(state.subtitleTracks) { track in
                    Text(track.displayName).tag(Int?.some(track.number))
                }
            }
            if state.subtitleTracks.contains(where: \.isSelected) {
                Section("Timing: \(state.subtitleDelay.formatted(.number.precision(.fractionLength(1)))) s") {
                    Button("Show Earlier", systemImage: "minus") { remote.send(.adjustSubtitleDelay(by: -0.1)) }
                        .menuActionDismissBehavior(.disabled)
                    Button("Show Later", systemImage: "plus") { remote.send(.adjustSubtitleDelay(by: 0.1)) }
                        .menuActionDismissBehavior(.disabled)
                }
            }
        } label: {
            optionLabel("Subtitles", systemImage: state.subtitleTracks.contains(where: \.isSelected) ? "captions.bubble.fill" : "captions.bubble")
        }
        .disabled(state.subtitleTracks.isEmpty)
    }

    private func audioMenu(_ state: PlayerState) -> some View {
        Menu {
            Picker("Audio", selection: Binding(
                get: { state.audioTracks.first(where: \.isSelected)?.number },
                set: { remote.send(.selectAudio($0)) }
            )) {
                ForEach(state.audioTracks) { track in
                    Text(track.displayName).tag(Int?.some(track.number))
                }
            }
        } label: {
            optionLabel("Audio", systemImage: "waveform")
        }
        .disabled(state.audioTracks.count < 2)
    }

    private func speedMenu(_ state: PlayerState) -> some View {
        Menu {
            Picker("Speed", selection: Binding(
                get: { state.speed },
                set: { remote.send(.setSpeed($0)) }
            )) {
                ForEach([0.5, 0.75, 1, 1.25, 1.5, 2], id: \.self) { speed in
                    Text(formatSpeed(speed)).tag(speed)
                }
            }
        } label: {
            Text(formatSpeed(state.speed))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .frame(width: 52, height: 52)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Speed \(formatSpeed(state.speed))")
        }
    }

    private func optionLabel(_ title: String, systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 18, weight: .medium))
            .frame(width: 52, height: 52)
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel(title)
    }
}
