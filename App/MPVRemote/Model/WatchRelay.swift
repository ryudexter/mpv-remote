import Foundation
import RemoteProtocol
import WatchConnectivity

/// Passes the Watch app's commands to `RemoteController`, and keeps the Watch
/// up to date with the computer and what's playing.
///
/// The Watch can't open the companion's WebSocket (watchOS restricts low-level
/// networking), so the iPhone does the talking. WatchConnectivity wakes this app
/// in the background to handle a message.
nonisolated final class WatchRelay: NSObject, WCSessionDelegate, @unchecked Sendable {
    typealias Handler = @MainActor @Sendable (WatchMessage) -> WatchState?

    private let handler: Handler
    /// The state last sent, so an update that changes nothing the Watch shows
    /// isn't sent again. Only touched on the main actor.
    private var lastPushed: WatchState?

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Sends the latest state: straight away while the Watch app is open, and as
    /// the application context, which the Watch app finds when it next opens.
    @MainActor
    func push(_ state: WatchState) {
        let session = WCSession.default
        guard WCSession.isSupported(), session.activationState == .activated, session.isWatchAppInstalled,
              lastPushed.map(state.differsVisibly) ?? true,
              let message = try? WatchMessage.state(state).watchConnectivityMessage()
        else { return }
        lastPushed = state
        try? session.updateApplicationContext(message)
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil)
        }
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        let reply = Reply(replyHandler)
        handle(message) { reply.send($0) }
    }

    /// Commands come without a reply handler, so the Watch never waits on the
    /// iPhone between them.
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handle(message) { _ in }
    }

    /// In the order they arrived, so a quick run of swipes reaches mpv in order.
    private func handle(_ message: [String: Any], then reply: @escaping @Sendable (WatchState?) -> Void) {
        guard let watchMessage = WatchMessage(watchConnectivityMessage: message) else {
            reply(nil)
            return
        }
        DispatchQueue.main.async { [handler] in
            MainActor.assumeIsolated {
                reply(handler(watchMessage))
            }
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // The user switched to another Watch; start talking to the new one.
        session.activate()
    }

    /// WatchConnectivity's reply handler isn't marked Sendable, but it's safe to
    /// call from any thread.
    private struct Reply: @unchecked Sendable {
        let handler: ([String: Any]) -> Void
        init(_ handler: @escaping ([String: Any]) -> Void) { self.handler = handler }

        func send(_ state: WatchState?) {
            handler((try? state.map { try WatchMessage.state($0).watchConnectivityMessage() }) ?? [:])
        }
    }
}

private extension WatchState {
    /// The companion resyncs the position every second while playing, which the
    /// Watch works out for itself; only a jump, like a seek, is worth sending.
    nonisolated func differsVisibly(from other: WatchState) -> Bool {
        var a = self, b = other
        a.player.position = nil
        b.player.position = nil
        a.positionDate = .distantPast
        b.positionDate = .distantPast
        return a != b || abs(position(at: positionDate) - other.position(at: positionDate)) > 1
    }
}
