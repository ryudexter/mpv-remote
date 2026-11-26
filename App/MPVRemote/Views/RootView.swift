import SwiftUI

struct RootView: View {
    @Environment(RemoteController.self) private var remote
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if remote.computer?.token != nil {
                NowPlayingView()
            } else {
                ComputerPickerView()
            }
        }
        .animation(.smooth, value: remote.computer?.token != nil)
        .sheet(isPresented: .constant(remote.status == .needsPairing)) {
            // Passed in again because a sheet on a Mac running the iPhone app
            // doesn't inherit it, and reading it there crashes.
            PairingView()
                .environment(remote)
        }
        // The tick out of the Dynamic Island or the notch once mpv's computer
        // has accepted the connection, in a window over this one's.
        .background { ConnectedTickWindow(remote: remote) }
        // Initially too: an app the Watch started in the background may have
        // let its connection go before anything was on screen.
        .onChange(of: scenePhase, initial: true) { _, phase in
            remote.setActive(phase != .background)
        }
    }
}
