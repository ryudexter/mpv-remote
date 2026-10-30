import Foundation
import Network
import RemoteProtocol

/// Serves the phone app: a WebSocket listener advertised over Bonjour.
@MainActor
final class RemoteServer {
    var onCommand: ((PlayerCommand) -> Void)?
    /// Called whenever a phone is let in, so it can be brought up to date.
    var onPhoneConnected: (() -> Void)?
    /// Called if the listener stops for good, as when another program already
    /// has the port (`.posix(.EADDRINUSE)`). Nothing is served after that.
    var onFailure: ((NWError) -> Void)?
    /// Called each time the listener is up and phones can connect.
    var onListening: (() -> Void)?

    /// Whether any paired phone is connected right now.
    var hasPhones: Bool { sessions.values.contains(where: \.isAuthorized) }

    private let computerName: String
    private let port: NWEndpoint.Port
    private let pairing: PairingStore
    private var listener: NWListener?
    private var restart: Task<Void, Never>?
    private var sessions: [ObjectIdentifier: ClientSession] = [:]

    private var latestState = PlayerState()
    private(set) var latestThumbnail: Data?
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
        listener.stateUpdateHandler = { [weak self, port] state in
            switch state {
            case .ready:
                log("Listening on port \(port), advertised over Bonjour")
                MainActor.assumeIsolated { self?.onListening?() }
            case .failed(let error): MainActor.assumeIsolated { self?.fail(error) }
            default: break
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            MainActor.assumeIsolated { self?.accept(connection) }
        }
        listener.start(queue: .main)
        self.listener = listener
    }

    private func fail(_ error: NWError) {
        listener?.cancel()
        listener = nil
        onFailure?(error)
    }

    /// Starts listening again after `delay`, as when another companion had the
    /// port and may let go of it. Asks `onFailure` again if it still can't.
    func startAgain(after delay: Duration) {
        restart?.cancel()
        restart = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self, self.listener == nil else { return }
            do {
                try self.start()
            } catch let error as NWError {
                self.fail(error)
            } catch {
                self.fail(.posix(.EIO))
            }
        }
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

    /// Sends a new frame, or nil to clear it, to every paired phone.
    func updateThumbnail(_ jpeg: Data?) {
        guard jpeg != latestThumbnail else { return }
        latestThumbnail = jpeg
        for session in sessions.values where session.isAuthorized {
            session.send(.thumbnail(jpeg: jpeg))
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
        let session = ClientSession(connection: connection, source: Self.source(of: connection))
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
                pairing.announceCode(reason: "A phone wants to pair.", to: session.source)
            }
        case .pair(let code, let deviceName, let deviceID):
            switch pairing.pair(code: code, deviceName: deviceName, deviceID: deviceID, from: session.source) {
            case .paired(let token):
                session.send(.paired(token: token))
                authorize(session, deviceName: deviceName)
                log("Paired with \(deviceName)")
            case .wrongCode, .lockedOut:
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

    /// Who is on the other end, as `PairingGuard` counts them.
    private static func source(of connection: NWConnection) -> String {
        guard case .hostPort(let host, _) = connection.endpoint else { return "unknown" }
        switch host {
        case .ipv4(let address):
            return PairingGuard.source(of: Array(address.rawValue))
        case .ipv6(let address):
            if let mapped = address.asIPv4 { return PairingGuard.source(of: Array(mapped.rawValue)) }
            return PairingGuard.source(of: Array(address.rawValue))
        case .name(let name, _):
            return name
        @unknown default:
            return "unknown"
        }
    }

    private func authorize(_ session: ClientSession, deviceName: String) {
        session.isAuthorized = true
        session.deviceName = deviceName
        session.send(.welcome(computerName: computerName))
        session.send(.state(latestState))
        if let latestThumbnail { session.send(.thumbnail(jpeg: latestThumbnail)) }
        log("\(deviceName) connected")
        onPhoneConnected?()
    }
}

/// One phone's WebSocket connection.
@MainActor
final class ClientSession {
    /// Where the phone is connecting from, for rationing pairing attempts.
    let source: String
    var isAuthorized = false
    var deviceName = "A phone"
    var onMessage: ((ClientSession, ClientMessage) -> Void)?
    var onClose: ((ClientSession) -> Void)?

    /// How long a new connection has to say hello.
    static let helloTimeout: Duration = .seconds(10)
    /// How long one that isn't paired yet may wait, e.g. for someone to read out the code.
    static let pairingTimeout: Duration = .seconds(300)

    private let connection: NWConnection
    private var isClosed = false
    private var hasSpoken = false
    private var timeouts: [Task<Void, Never>] = []

    init(connection: NWConnection, source: String) {
        self.connection = connection
        self.source = source
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
        // Phones that never say hello, or never get as far as pairing, shouldn't be kept for ever.
        closeAfter(Self.helloTimeout) { !$0.hasSpoken }
        closeAfter(Self.pairingTimeout) { !$0.isAuthorized }
    }

    private func closeAfter(_ delay: Duration, if condition: @escaping @MainActor (ClientSession) -> Bool) {
        timeouts.append(Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self, condition(self) else { return }
            log("Closing a connection from \(self.source) that didn't \(self.hasSpoken ? "pair" : "say hello") in time")
            self.close()
        })
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
                    self.hasSpoken = true
                    self.onMessage?(self, message)
                }
                self.receive()
            }
        }
    }

    private func close() {
        guard !isClosed else { return }
        isClosed = true
        timeouts.forEach { $0.cancel() }
        connection.cancel()
        onClose?(self)
    }
}
