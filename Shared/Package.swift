// swift-tools-version: 6.0
import PackageDescription

// The message format spoken between the iPhone app and the companion on the
// computer. Both sides import this, so they can never disagree about it.
let package = Package(
    name: "Shared",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "RemoteProtocol", targets: ["RemoteProtocol"]),
    ],
    targets: [
        .target(name: "RemoteProtocol"),
    ]
)
