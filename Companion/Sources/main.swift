import Foundation
import RemoteProtocol

let usage = """
    Usage: mpv-remote [--socket PATH] [--port PORT] [--name NAME] [--exit-with-mpv] [--log FILE]

      --socket PATH    mpv's IPC socket, as given to --input-ipc-server
                       (default: /tmp/mpvsocket)
      --port PORT      port for the phone app (default: \(RemoteService.defaultPort))
      --name NAME      how this computer appears on the phone
                       (default: the computer's name)
      --exit-with-mpv  quit when mpv does, instead of waiting for it to come
                       back (how the mpv script runs it)
      --log FILE       append output to FILE instead of printing it
    """

var socketPath = "/tmp/mpvsocket"
var port = RemoteService.defaultPort
var computerName = Host.current().localizedName ?? "Mac"
var exitsWithMPV = false
var logPath: String?

var arguments = CommandLine.arguments.dropFirst()
while let argument = arguments.popFirst() {
    switch argument {
    case "--socket": socketPath = arguments.popFirst() ?? socketPath
    case "--port": port = arguments.popFirst().flatMap(UInt16.init) ?? port
    case "--name": computerName = arguments.popFirst() ?? computerName
    case "--exit-with-mpv": exitsWithMPV = true
    case "--log": logPath = arguments.popFirst()
    case "-h", "--help":
        print(usage)
        exit(0)
    default:
        print("Unknown option \(argument)\n\n\(usage)")
        exit(64)
    }
}

func log(_ message: String) {
    print("[\(Date.now.formatted(date: .omitted, time: .standard))] \(message)")
}

if let logPath {
    try? FileManager.default.createDirectory(at: URL(filePath: logPath).deletingLastPathComponent(), withIntermediateDirectories: true)
    freopen(logPath, "a", stdout)
    freopen(logPath, "a", stderr)
}
// Logs should appear as they happen even when stdout is a pipe or a file.
setvbuf(stdout, nil, _IOLBF, 0)
signal(SIGPIPE, SIG_IGN)

let pairing = PairingStore()
let server = RemoteServer(computerName: computerName, port: port, pairing: pairing)
let mpv = MPVConnection(socketPath: socketPath, exitsWithMPV: exitsWithMPV)
let thumbnails = Thumbnailer(mpv: mpv, server: server)
mpv.onChange = { state, positionOnly in
    server.update(state, positionOnly: positionOnly)
    if !positionOnly { thumbnails.stateChanged(state) }
}
mpv.onEvent = { event in thumbnails.handle(event: event) }
server.onCommand = { command in mpv.perform(command) }
server.onPhoneConnected = { thumbnails.phoneConnected() }
/// Whether the port was already taken when we last tried, so a long wait logs once.
var waitingForPort = false
server.onFailure = { error in
    if case .posix(.EADDRINUSE) = error {
        // Most likely another mpv window: the first one's helper serves the phone.
        // Keep watching mpv and take the port over once that helper quits, so this
        // mpv can be controlled too when the first one is closed.
        if !waitingForPort {
            log("Port \(port) is already in use, probably by another MPV Remote companion; waiting for it to quit")
            waitingForPort = true
        }
        server.startAgain(after: .seconds(2))
        return
    }
    log("Listener failed: \(error)")
    exit(1)
}
server.onListening = {
    if waitingForPort { log("Port \(port) is free now") }
    waitingForPort = false
    // Phones paired through the helper that had the port aren't in our copy.
    pairing.reload()
}
// The code also appears over the video, where whoever is pairing is already looking.
pairing.onAnnounce = { code in mpv.showText("MPV Remote pairing code: \(code)", seconds: 20) }

print("""
    MPV Remote companion
      Computer:     \(computerName)
      mpv socket:   \(socketPath)
      Pairing code: \(pairing.code)

    """)
if !exitsWithMPV {
    print("mpv must be started with --input-ipc-server=\(socketPath) (or have it in mpv.conf).\n")
}

do {
    try server.start()
} catch {
    log("Could not listen on port \(port): \(error)")
    exit(1)
}
mpv.start()
// Not dispatchMain(): that retires the main thread, and everything here is
// @MainActor, which Swift checks against the main thread itself.
CFRunLoopRun()
