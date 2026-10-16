import SwiftUI

@main
struct MPVRemoteApp: App {
    @State private var remote = RemoteController()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(remote)
        }
    }
}
