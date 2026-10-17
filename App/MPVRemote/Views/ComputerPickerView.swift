import SwiftUI

/// First run: find the computer running the companion.
struct ComputerPickerView: View {
    @Environment(RemoteController.self) private var remote
    @State private var browser = ComputerBrowser()
    @State private var isEnteringAddress = false
    @State private var address = ""

    /// MPV Player: Tiger Version, whose installer also adds the MPV Remote script.
    private static let mpvSetupURL = URL(string: "https://github.com/ryudexter/mpv-macos-setup#quick-start")!
    private static let scriptSetupURL = URL(string: "https://github.com/ryudexter/mpv-remote/blob/main/SUPPORT.md#setting-up")!

    var body: some View {
        NavigationStack {
            List {
                Section {
                    header
                }
                .listRowBackground(Color.clear)

                Section {
                    if browser.names.isEmpty {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Looking for computers…")
                                .foregroundStyle(.secondary)
                        }
                    }
                    ForEach(browser.names, id: \.self) { name in
                        Button {
                            remote.choose(SavedComputer(name: name, address: .bonjour(name: name)))
                        } label: {
                            row(name: name)
                        }
                    }
                } header: {
                    Text("On This Network")
                } footer: {
                    Text("Open a video in mpv on a Mac with the MPV Remote script and it will show up here.")
                }

                Section {
                    Button("Enter Address Manually", systemImage: "keyboard") {
                        isEnteringAddress = true
                    }
                }

                Section {
                    Link(destination: Self.mpvSetupURL) {
                        Label("Get mpv for Mac", systemImage: "arrow.down.circle")
                    }
                    Link(destination: Self.scriptSetupURL) {
                        Label("Add the Script to Your mpv", systemImage: "puzzlepiece.extension")
                    }
                } header: {
                    Text("Set Up Your Mac")
                } footer: {
                    Text("MPV Player: Tiger Version is the mpv setup this app is made with, and it comes with the MPV Remote script built in. One line in Terminal on your Mac installs both. Already use mpv? Just add the script.")
                }

                Section {
                    Button("Try the Demo", systemImage: "play.tv") {
                        remote.startDemo()
                    }
                } footer: {
                    Text("Explore the app with a pretend player. No Mac needed.")
                }
            }
            .navigationTitle("Connect")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Computer Address", isPresented: $isEnteringAddress) {
                TextField("192.168.1.20", text: $address)
                    .keyboardType(.numbersAndPunctuation)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Connect") {
                    if let computer = SavedComputer(manualAddress: address) {
                        remote.choose(computer)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The IP address or name of the Mac running mpv with the MPV Remote script.")
            }
        }
        .onAppear { browser.start() }
        .onDisappear { browser.stop() }
    }

    private var header: some View {
        VStack(spacing: 14) {
            Image(systemName: "play.rectangle.on.rectangle.fill")
                .font(.system(size: 64, weight: .semibold))
                .foregroundStyle(.tint)
                .symbolRenderingMode(.hierarchical)
            Text("Control mpv from your iPhone")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private func row(name: String) -> some View {
        HStack {
            Label {
                Text(name).foregroundStyle(Color.primary)
            } icon: {
                Image(systemName: "desktopcomputer")
            }
            Spacer()
            if remote.computer?.name == name {
                switch remote.status {
                case .unreachable:
                    Text("Can't connect").foregroundStyle(.secondary)
                default:
                    ProgressView()
                }
            }
        }
    }
}
