import Foundation
import Network
import RemoteProtocol

/// Serves the phone app: a WebSocket listener advertised over Bonjour.
@MainActor
final class RemoteServer {
    var onCommand: ((PlayerCommand) -> Void)?

    private let computerName: String
    private let port: NWEndpoint.Port
    private let pairing: PairingStore
    private var listener: NWListener?
    private var sessions: [ObjectIdentifier: ClientSession] = [:]

    private var latestState = PlayerState()
    private var sentState = PlayerState()
    private var sentAt = Date.distantPast
    private var sendScheduled = false

    init(computerName: String, port: UInt16, pairing: PairingStore) {
        self.computerName = computerName
        self.port = NWEndpoint.Port(rawValue: port) ?? 7655
        self.pairing = pairing
    }

    func start() throws {
        let parameters = NWParameters.tcp
        let websocket = NWProtocolWebSocket.Options()
        websocket.autoReplyPing = true
        parameters.defaultProtocolStack.applicationProtocols.insert(websocket, at: 0)

        let listener = try NWListener(using: parameters, on: port)
        listener.service = NWListener.Service(name: computerName, type: RemoteService.bonjourType)
        listener.stateUpdateHandler = { [port] state in
            switch state {
            case .ready: log("Listening on port \(port), advertised over Bonjour")
            case .failed(let error): log("Listener failed: \(error)"); exit(1)
            default: break
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            MainActor.assumeIsolated { self?.accept(connection) }
        }
        listener.start(queue: .main)
        self.listener = listener
    }

    /// Takes the latest player state and pushes it to paired phones, coalescing
    /// bursts (loading a file changes a dozen properties at once) into one message.
    func update(_ state: PlayerState, positionOnly: Bool) {
        latestState = state
        if positionOnly && !state.isPaused && !positionJumped(state) && Date.now.timeIntervalSince(sentAt) < 1 {
            // The phone extrapolates the position during playback, so a resync
            // once a second is plenty. Seeks still go out at once (see above).
            return
        }
        guard !sendScheduled else { return }
        sendScheduled = true
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(30))
            self?.broadcastLatest()
        }
    }

    private func positionJumped(_ state: PlayerState) -> Bool {
        guard let position = state.position, let previous = sentState.position else { return true }
        let expected = previous + Date.now.timeIntervalSince(sentAt) * sentState.speed
        return abs(position - expected) > 1.5
    }

    private func broadcastLatest() {
        sendScheduled = false
        sentState = latestState
        sentAt = .now
        for session in sessions.values where session.isAuthorized {
            session.send(.state(latestState))
        }
    }

    // MARK: Sessions

    private func accept(_ connection: NWConnection) {
        let session = ClientSession(connection: connection)
        let id = ObjectIdentifier(session)
        session.onMessage = { [weak self] session, message in self?.handle(message, from: session) }
        session.onClose = { [weak self] session in
            if session.isAuthorized { log("\(session.deviceName) disconnected") }
            self?.sessions[id] = nil
        }
        sessions[id] = session
        session.start()
    }

    private func handle(_ message: ClientMessage, from session: ClientSession) {
        switch message {
        case .hello(_, let token):
            if let token, let deviceName = pairing.deviceName(forToken: token) {
                authorize(session, deviceName: deviceName)
            } else {
                session.send(.pairingRequired(computerName: computerName))
                pairing.announceCode(reason: "A phone wants to pair.")
            }
        case .pair(let code, let deviceName):
            if let token = pairing.pair(code: code, deviceName: deviceName) {
                session.send(.paired(token: token))
                authorize(session, deviceName: deviceName)
                log("Paired with \(deviceName)")
            } else {
                session.send(.pairingFailed)
            }
        case .command(let command):
            guard session.isAuthorized else {
                session.send(.pairingRequired(computerName: computerName))
                return
            }
            onCommand?(command)
        }
    }

    private func authorize(_ session: ClientSession, deviceName: String) {
        session.isAuthorized = true
        session.deviceName = deviceName
        session.send(.welcome(computerName: computerName))
        session.send(.state(latestState))
        log("\(deviceName) connected")
    }
}

/// One phone's WebSocket connection.
@MainActor
final class ClientSession {
    var isAuthorized = false
    var deviceName = "A phone"
    var onMessage: ((ClientSession, ClientMessage) -> Void)?
    var onClose: ((ClientSession) -> Void)?

    private let connection: NWConnection
    private var isClosed = false

    init(connection: NWConnection) {
        self.connection = connection
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed, .cancelled:
                MainActor.assumeIsolated { self?.close() }
            default:
                break
            }
        }
        connection.start(queue: .main)
        receive()
    }

    func send(_ message: ServerMessage) {
        guard !isClosed, let data = try? JSONEncoder().encode(message) else { return }
        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(identifier: "message", metadata: [metadata])
        connection.send(content: data, contentContext: context, isComplete: true, completion: .idempotent)
    }

    private func receive() {
        connection.receiveMessage { [weak self] data, context, _, error in
            MainActor.assumeIsolated {
                guard let self, !self.isClosed else { return }
                if error != nil || context?.isFinal == true {
                    self.close()
                    return
                }
                if let data, let message = try? JSONDecoder().decode(ClientMessage.self, from: data) {
                    self.onMessage?(self, message)
                }
                self.receive()
            }
        }
    }

    private func close() {
        guard !isClosed else { return }
        isClosed = true
        connection.cancel()
        onClose?(self)
    }
}
