// swift-tools-version: 6.2
import PackageDescription

// A stand-in Mac for the App Store screenshots: the companion's own server and
// pairing, playing the app's demo series and sending one fixed frame, so the
// phone shows a real connection to "MacBook Pro" with a picture.
let package = Package(
    name: "ScreenshotCompanion",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../../../Shared"),
    ],
    targets: [
        .executableTarget(
            name: "screenshot-companion",
            dependencies: [.product(name: "RemoteProtocol", package: "Shared")],
            // DemoPlayer comes from the app, which is main-actor by default.
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
    ]
)
