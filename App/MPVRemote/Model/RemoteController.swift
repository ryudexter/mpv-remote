import Foundation
import Network
import Observation
import RemoteProtocol
import UIKit

/// The app's one connection to a companion: pairing, the live player state,
/// and sending commands.
@Observable
final class RemoteController {
    enum Status: Equatable {
        case connecting
        case needsPairing
        case connected
        /// The last attempt failed; another one is scheduled.
        case unreachable
    }

    private(set) var computer: SavedComputer?
    private(set) var status = Status.connecting
    private(set) var state = PlayerState()
    /// Set when the last pairing code was wrong, cleared on the next attempt.
    private(set) var pairingFailed = false

    /// Set while the built-in demo stands in for a real computer.
    private var demo: DemoPlayer?
    var isDemo: Bool { demo != nil }

    /// When `state` arrived, so playback position can be extrapolated between updates.
    private var stateReceivedAt = Date.now
    private var connection: NWConnection?
    private var retryTask: Task<Void, Never>?
    private var isActive = true

    init() {
        computer = SavedComputer.load()
        if computer != nil { connect() }
    }

    /// Where playback is at `date`, assuming it carried on since the last update.
    func position(at date: Date) -> Double {
        guard let position = state.position else { return 0 }
        guard !state.isPaused else { return position }
        let extrapolated = position + date.timeIntervalSince(stateReceivedAt) * state.speed
        return min(extrapolated, state.duration ?? extrapolated)
    }

    // MARK: Choosing a computer

    func choose(_ computer: SavedComputer) {
        self.computer = computer
        computer.save()
        connect()
    }

    /// Plays with the pretend player instead of a computer. Not saved, so the
    /// next launch starts at the computer list again.
    func startDemo() {
        disconnect()
        let demo = DemoPlayer()
        demo.onChange = { [weak self] state in self?.receive(state) }
        self.demo = demo
        computer = SavedComputer(name: "Demo Mac", address: .demo, token: "demo")
        status = .connected
        receive(demo.state)
    }

    func forgetComputer() {
        disconnect()
        demo = nil
        SavedComputer.forget()
        computer = nil
        status = .connecting
        state = PlayerState()
        pairingFailed = false
    }

    func pair(code: String) {
        pairingFailed = false
        send(.pair(code: code, deviceName: UIDevice.current.name))
    }

    // MARK: App lifecycle

    /// iOS suspends the app soon after it leaves the screen, so the connection
    /// is dropped on purpose there and made again on return.
    func setActive(_ active: Bool) {
        guard active != isActive else { return }
        isActive = active
        if active {
            connect()
        } else {
            disconnect()
        }
    }

    // MARK: Commands

    func send(_ command: PlayerCommand) {
        if let demo {
            demo.perform(command)
            return
        }
        applyOptimistically(command)
        send(.command(command))
    }

    /// Shows the effect of a command right away instead of after the round
    /// trip; the companion's next update confirms or corrects it.
    private func applyOptimistically(_ command: PlayerCommand) {
        let now = Date.now
        switch command {
        case .togglePause:
            reanchorPosition(to: position(at: now))
            state.isPaused.toggle()
        case .seek(let seconds):
            reanchorPosition(to: seconds)
        case .skip(let seconds):
            reanchorPosition(to: min(max(0, position(at: now) + seconds), state.duration ?? .infinity))
        case .setVolume(let volume):
            state.volume = volume
        case .toggleMute:
            state.isMuted.toggle()
        case .setSpeed(let speed):
            reanchorPosition(to: position(at: now))
            state.speed = speed
        case .selectAudio(let id):
            select(id, kind: .audio)
        case .selectSubtitle(let id):
            select(id, kind: .subtitle)
        default:
            break
        }
    }

    private func reanchorPosition(to seconds: Double) {
        state.position = seconds
        stateReceivedAt = .now
    }

    private func select(_ id: Int?, kind: Track.Kind) {
        for index in state.tracks.indices where state.tracks[index].kind == kind {
            state.tracks[index].isSelected = state.tracks[index].number == id
        }
    }

    // MARK: Connection

    func connect() {
        guard let computer, let endpoint = computer.endpoint else { return }
        disconnect()
        if status != .needsPairing { status = .connecting }

        let parameters = NWParameters.tcp
        let websocket = NWProtocolWebSocket.Options()
        websocket.autoReplyPing = true
        parameters.defaultProtocolStack.applicationProtocols.insert(websocket, at: 0)

        let connection = NWConnection(to: endpoint, using: parameters)
        connection.stateUpdateHandler = { [weak self] newState in
            MainActor.assumeIsolated { self?.connection(connection, changedTo: newState) }
        }
        self.connection = connection
        connection.start(queue: .main)
        receive(on: connection)
    }

    private func disconnect() {
        retryTask?.cancel()
        retryTask = nil
        connection?.cancel()
        connection = nil
    }

    private func connection(_ connection: NWConnection, changedTo newState: NWConnection.State) {
        guard connection === self.connection else { return }
        switch newState {
        case .ready:
            send(.hello(version: RemoteService.protocolVersion, token: computer?.token))
        case .waiting, .failed:
            connectionLost()
        default:
            break
        }
    }

    private func connectionLost() {
        disconnect()
        if status != .needsPairing { status = .unreachable }
        guard isActive else { return }
        retryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.connect()
        }
    }

    private func receive(on connection: NWConnection) {
        connection.receiveMessage { [weak self] data, context, _, error in
            MainActor.assumeIsolated {
                guard let self, connection === self.connection else { return }
                if error != nil || context?.isFinal == true {
                    self.connectionLost()
                    return
                }
                if let data, let message = try? JSONDecoder().decode(ServerMessage.self, from: data) {
                    self.handle(message)
                }
                self.receive(on: connection)
            }
        }
    }

    private func handle(_ message: ServerMessage) {
        switch message {
        case .welcome(let computerName):
            status = .connected
            if computer?.name != computerName {
                computer?.name = computerName
                computer?.save()
            }
        case .pairingRequired:
            computer?.token = nil
            status = .needsPairing
        case .paired(let token):
            computer?.token = token
            computer?.save()
        case .pairingFailed:
            pairingFailed = true
        case .state(let newState):
            receive(newState)
        }
    }

    private func receive(_ newState: PlayerState) {
        state = newState
        stateReceivedAt = .now
    }

    private func send(_ message: ClientMessage) {
        guard let connection, let data = try? JSONEncoder().encode(message) else { return }
        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(identifier: "message", metadata: [metadata])
        connection.send(content: data, contentContext: context, isComplete: true, completion: .idempotent)
    }
}
