// swift-tools-version: 6.0
import PackageDescription

// The program that runs on the computer next to mpv: it talks to mpv over its
// local IPC socket and serves the iPhone app over Wi-Fi.
let package = Package(
    name: "Companion",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../Shared"),
    ],
    targets: [
        .executableTarget(
            name: "mpv-remote",
            dependencies: [.product(name: "RemoteProtocol", package: "Shared")],
            path: "Sources"
        ),
    ]
)
