import RemoteProtocol
import SwiftUI

/// The playlist and the current file's chapters.
struct QueueView: View {
    @Environment(RemoteController.self) private var remote
    @Environment(\.dismiss) private var dismiss
    @State private var tab = Tab.playlist

    private enum Tab {
        case playlist, chapters
    }

    var body: some View {
        let state = remote.state
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    switch tab {
                    case .playlist:
                        ForEach(state.playlist) { entry in
                            row(entry.title, detail: "\(entry.index + 1)", isCurrent: entry.isCurrent) {
                                remote.send(.playlistPlay(index: entry.index))
                            }
                            .id(entry.index)
                        }
                    case .chapters:
                        ForEach(state.chapters) { chapter in
                            row(chapter.title ?? "Chapter \(chapter.index + 1)", detail: formatTime(chapter.time),
                                isCurrent: chapter.index == state.chapterIndex) {
                                remote.send(.selectChapter(chapter.index))
                            }
                            .id(chapter.index)
                        }
                    }
                }
                .onAppear {
                    if state.playlist.count < 2 { tab = .chapters }
                    proxy.scrollTo(tab == .playlist ? state.playlistIndex : state.chapterIndex, anchor: .center)
                }
            }
            .navigationTitle(tab == .playlist ? "Playlist" : "Chapters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if state.playlist.count > 1 && !state.chapters.isEmpty {
                    ToolbarItem(placement: .principal) {
                        Picker("Show", selection: $tab) {
                            Text("Playlist").tag(Tab.playlist)
                            Text("Chapters").tag(Tab.chapters)
                        }
                        .pickerStyle(.segmented)
                        .fixedSize()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func row(_ title: String, detail: String, isCurrent: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    if isCurrent {
                        Image(systemName: "waveform")
                            .symbolEffect(.variableColor.iterative, isActive: !remote.state.isPaused)
                            .foregroundStyle(.tint)
                    } else {
                        Text(detail)
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.subheadline.monospacedDigit())
                .frame(minWidth: 44, alignment: .leading)
                Text(title)
                    .fontWeight(isCurrent ? .semibold : .regular)
                    // Color.primary, not .primary: inside a button that means the tint.
                    .foregroundStyle(isCurrent ? Color.accentColor : Color.primary)
                    .lineLimit(2)
            }
        }
    }
}
