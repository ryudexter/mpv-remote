import Foundation
import RemoteProtocol

// screenshot-companion <frame.jpg> [--port PORT] [--at SECONDS]
//
// Serves the demo series as "MacBook Pro", with the frame from
// make-demo-frame.swift. RemoteServer, PairingStore and DemoPlayer are the
// real ones, linked in.

nonisolated func log(_ message: String) {
    print("[\(Date.now.formatted(date: .omitted, time: .standard))] \(message)")
}
setvbuf(stdout, nil, _IOLBF, 0)
signal(SIGPIPE, SIG_IGN)

var arguments = CommandLine.arguments.dropFirst()
guard let framePath = arguments.popFirst(), let frame = FileManager.default.contents(atPath: framePath) else {
    print("Usage: screenshot-companion <frame.jpg> [--port PORT] [--at SECONDS]")
    exit(64)
}
var port = RemoteService.defaultPort
var start: Double?
while let argument = arguments.popFirst() {
    switch argument {
    case "--port": port = arguments.popFirst().flatMap(UInt16.init) ?? port
    case "--at": start = arguments.popFirst().flatMap(Double.init)
    default:
        print("Unknown option \(argument)")
        exit(64)
    }
}

let pairing = PairingStore()
let server = RemoteServer(computerName: "MacBook Pro", port: port, pairing: pairing)
let demo = DemoPlayer()
if let start { demo.perform(.seek(to: start)) }
server.update(demo.state, positionOnly: false)
demo.onChange = { state in server.update(state, positionOnly: false) }
server.onCommand = { command in demo.perform(command) }
server.updateThumbnail(frame)
pairing.onAnnounce = { code in log("Pairing code: \(code)") }
server.onFailure = { error in
    log("Listener failed: \(error)")
    exit(1)
}

log("Pairing code: \(pairing.code)")
do {
    try server.start()
} catch {
    log("Could not listen on port \(port): \(error)")
    exit(1)
}
CFRunLoopRun()
