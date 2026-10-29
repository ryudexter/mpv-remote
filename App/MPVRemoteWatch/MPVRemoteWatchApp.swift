import SwiftUI

@main
struct MPVRemoteWatchApp: App {
    @State private var link = RemoteLink()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                WatchRemoteView()
            }
            .tint(.remotePurple)
            .environment(link)
        }
    }
}

extension Color {
    /// The purple the iPhone app is tinted with (its AccentColor), which the
    /// remote is tinted with too.
    static let remotePurple = Color(red: 0.655, green: 0.545, blue: 0.980)
}
