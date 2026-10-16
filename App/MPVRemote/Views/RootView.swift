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
            PairingView()
        }
        .onChange(of: scenePhase) { _, phase in
            remote.setActive(phase != .background)
        }
    }
}
