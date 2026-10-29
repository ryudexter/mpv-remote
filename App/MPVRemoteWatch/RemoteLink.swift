import Foundation
import Observation
import RemoteProtocol
import WatchConnectivity

/// Gets the Watch's commands to mpv through the iPhone app, which forwards them
/// over its own connection to the computer. The iPhone app doesn't need to be
/// open; WatchConnectivity wakes it in the background.
@Observable
final class RemoteLink {
    private(set) var state: WatchState?
    var errorMessage: String?

    @ObservationIgnored private var delegate: SessionDelegate?
    /// Runs while the app is open, so the iPhone app stays awake and connected.
    @ObservationIgnored private var checkIns: Task<Void, Never>?
    /// What the last turn of the crown asked for. Just after one, the next steps
    /// from this, as what the iPhone reports may still be an echo of an earlier one.
    @ObservationIgnored private var lastVolumeChange: (volume: Double, date: Date)?
    /// When the iPhone made the newest state received.
    @ObservationIgnored private var newestReceived = Date.distantPast

    init() {
        let delegate = SessionDelegate { [weak self] state in
            Task { @MainActor in self?.receive(state) }
        } onActivated: { [weak self] in
            Task { @MainActor in self?.sessionDidActivate() }
        }
        self.delegate = delegate
        delegate.activate()
    }

    /// Something is loaded in mpv, so there's something to control.
    var isPlaying: Bool {
        guard let player = state?.player else { return false }
        return player.isRunning && !player.isIdle
    }

    func position(at date: Date) -> Double {
        state?.position(at: date) ?? 0
    }

    func send(_ command: PlayerCommand) {
        guard send(.command(command), expectsReply: false) else { return }
        applyOptimistically(command)
    }

    /// Moves to the next multiple of 5 up or down, within mpv's range, as the
    /// iPhone's volume buttons do.
    func changeVolume(up: Bool) {
        guard let player = state?.player else { return }
        let step = 5.0
        var current = player.volume
        if let lastVolumeChange, lastVolumeChange.date.timeIntervalSinceNow > -1 {
            current = lastVolumeChange.volume
        }
        let next = up
            ? ((current / step).rounded(.down) + 1) * step
            : ((current / step).rounded(.up) - 1) * step
        let volume = min(max(next, 0), max(player.maxVolume, 100))
        guard volume != current else { return }
        lastVolumeChange = (volume, .now)
        send(.setVolume(volume))
    }

    /// Has the iPhone connect to the computer now, before the first command.
    /// While the app stays open it checks in every 15 seconds, which keeps the
    /// iPhone app awake and its connection open.
    func appDidBecomeActive() {
        send(.requestState, quietly: true)
        checkIns?.cancel()
        checkIns = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard let self, !Task.isCancelled else { return }
                send(.requestState, quietly: true)
            }
        }
    }

    func appDidResignActive() {
        checkIns?.cancel()
        checkIns = nil
    }

    /// The app usually opens before WatchConnectivity is ready, so the first
    /// check-in waits for this.
    private func sessionDidActivate() {
        if checkIns != nil { send(.requestState, quietly: true) }
    }

    /// States come by three routes (replies, updates and the application
    /// context), which can overtake each other.
    private func receive(_ newState: WatchState) {
        guard newState.positionDate >= newestReceived else { return }
        newestReceived = newState.positionDate
        state = newState
    }

    /// Shows the effect of a command right away instead of after the round
    /// trip; the iPhone's next update confirms or corrects it.
    private func applyOptimistically(_ command: PlayerCommand) {
        guard var state else { return }
        let now = Date.now
        switch command {
        case .togglePause:
            if state.player.position != nil {
                state.player.position = state.position(at: now)
                state.positionDate = now
            }
            state.player.isPaused.toggle()
        case .skip(let seconds):
            state.player.position = min(max(0, state.position(at: now) + seconds), state.player.duration ?? .infinity)
            state.positionDate = now
        case .setVolume(let volume):
            state.player.volume = volume
        case .toggleMute:
            state.player.isMuted.toggle()
        case .toggleFullscreen:
            state.player.isFullscreen.toggle()
        case .selectAudio(let id):
            select(id, kind: .audio, in: &state.player)
        case .selectSubtitle(let id):
            select(id, kind: .subtitle, in: &state.player)
        default:
            return
        }
        self.state = state
    }

    private func select(_ id: Int?, kind: Track.Kind, in player: inout PlayerState) {
        for index in player.tracks.indices where player.tracks[index].kind == kind {
            player.tracks[index].isSelected = player.tracks[index].number == id
        }
    }

    /// - Parameters:
    ///   - quietly: for check-ins, which shouldn't show an error when the iPhone is away.
    ///   - expectsReply: commands don't, so the iPhone never holds up the next one.
    /// - Returns: Whether the message went out.
    @discardableResult
    private func send(_ message: WatchMessage, quietly: Bool = false, expectsReply: Bool = true) -> Bool {
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else {
            if !quietly { errorMessage = String(localized: "Can't reach your iPhone. Keep it nearby with Bluetooth or Wi-Fi on.") }
            return false
        }
        guard let payload = try? message.watchConnectivityMessage() else { return false }
        if !quietly, errorMessage != nil { errorMessage = nil }
        let failed: @Sendable (Error) -> Void = { [weak self] error in
            Task { @MainActor in
                if !quietly { self?.errorMessage = error.localizedDescription }
            }
        }
        guard expectsReply else {
            session.sendMessage(payload, replyHandler: nil, errorHandler: failed)
            return true
        }
        // @Sendable: WatchConnectivity calls these on its own queue. Inferred as
        // main-actor closures, they trap.
        session.sendMessage(payload) { @Sendable [weak self] reply in
            if case .state(let state) = WatchMessage(watchConnectivityMessage: reply) {
                Task { @MainActor in self?.receive(state) }
            }
        } errorHandler: { @Sendable error in
            failed(error)
        }
        return true
    }
}

private nonisolated final class SessionDelegate: NSObject, WCSessionDelegate, @unchecked Sendable {
    private let onState: @Sendable (WatchState) -> Void
    private let onActivated: @Sendable () -> Void

    init(onState: @escaping @Sendable (WatchState) -> Void, onActivated: @escaping @Sendable () -> Void) {
        self.onState = onState
        self.onActivated = onActivated
    }

    func activate() {
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // The iPhone's last update survives app launches; show it right away.
        receive(session.receivedApplicationContext)
        if activationState == .activated { onActivated() }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        receive(applicationContext)
    }

    /// Updates the iPhone sends while this app is open.
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        receive(message)
    }

    private func receive(_ message: [String: Any]) {
        if case .state(let state) = WatchMessage(watchConnectivityMessage: message) {
            onState(state)
        }
    }
}
