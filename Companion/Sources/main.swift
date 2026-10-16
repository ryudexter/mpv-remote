import Foundation
import RemoteProtocol

let usage = """
    Usage: mpv-remote [--socket PATH] [--port PORT] [--name NAME]

      --socket PATH  mpv's IPC socket, as given to --input-ipc-server
                     (default: /tmp/mpvsocket)
      --port PORT    port for the phone app (default: \(RemoteService.defaultPort))
      --name NAME    how this computer appears on the phone
                     (default: the computer's name)
    """

var socketPath = "/tmp/mpvsocket"
var port = RemoteService.defaultPort
var computerName = Host.current().localizedName ?? "Mac"

var arguments = CommandLine.arguments.dropFirst()
while let argument = arguments.popFirst() {
    switch argument {
    case "--socket": socketPath = arguments.popFirst() ?? socketPath
    case "--port": port = arguments.popFirst().flatMap(UInt16.init) ?? port
    case "--name": computerName = arguments.popFirst() ?? computerName
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

// Logs should appear as they happen even when stdout is a pipe or a file.
setvbuf(stdout, nil, _IOLBF, 0)
signal(SIGPIPE, SIG_IGN)

let pairing = PairingStore()
let server = RemoteServer(computerName: computerName, port: port, pairing: pairing)
let mpv = MPVConnection(socketPath: socketPath)
mpv.onChange = { state, positionOnly in server.update(state, positionOnly: positionOnly) }
server.onCommand = { command in mpv.perform(command) }

print("""
    MPV Remote companion
      Computer:     \(computerName)
      mpv socket:   \(socketPath)
      Pairing code: \(pairing.code)

    mpv must be started with --input-ipc-server=\(socketPath)
    (or have input-ipc-server=\(socketPath) in mpv.conf).

    """)

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
