import Foundation
import RemoteProtocol

extension Track {
    /// "Japanese Dub", "English", or "Commentary (English)".
    var displayName: String {
        let languageName = language.map { Locale.current.localizedString(forLanguageCode: $0) ?? $0.uppercased() }
        switch (title, languageName) {
        case let (title?, language?) where !title.localizedCaseInsensitiveContains(language):
            return "\(title) (\(language))"
        case let (title?, _):
            return title
        case let (nil, language?):
            return language
        case (nil, nil):
            return "Track \(number)"
        }
    }
}

extension PlayerState {
    var audioTracks: [Track] { tracks.filter { $0.kind == .audio } }
    var subtitleTracks: [Track] { tracks.filter { $0.kind == .subtitle } }
    var currentChapter: Chapter? { chapterIndex.flatMap { chapters.indices.contains($0) ? chapters[$0] : nil } }
}

/// "4:05" or "1:02:09".
func formatTime(_ seconds: Double) -> String {
    let total = Int(max(0, seconds))
    let hours = total / 3600, minutes = total / 60 % 60, secs = total % 60
    return hours > 0
        ? String(format: "%d:%02d:%02d", hours, minutes, secs)
        : String(format: "%d:%02d", minutes, secs)
}

/// "1×", "1.5×", "0.75×".
func formatSpeed(_ speed: Double) -> String {
    speed.formatted(.number.precision(.fractionLength(0...2))) + "×"
}
