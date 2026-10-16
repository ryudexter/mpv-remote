import SwiftUI

/// First run: find the computer running the companion.
struct ComputerPickerView: View {
    @Environment(RemoteController.self) private var remote
    @State private var browser = ComputerBrowser()
    @State private var isEnteringAddress = false
    @State private var address = ""

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
                    Text("Run the MPV Remote companion on the computer that plays your videos and it will show up here.")
                }

                Section {
                    Button("Enter Address Manually", systemImage: "keyboard") {
                        isEnteringAddress = true
                    }
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
                Text("The IP address or name of the computer running the companion.")
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
