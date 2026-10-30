import Foundation
import ImageIO
import RemoteProtocol
import UniformTypeIdentifiers

/// Keeps the phones' artwork showing the frame mpv is on: a new one shortly
/// after a file opens or a seek lands, as soon as playback pauses, and every
/// 20 seconds while it plays. Only while a phone is connected, so mpv does no
/// extra work otherwise.
@MainActor
final class Thumbnailer {
    private let mpv: MPVConnection
    private let server: RemoteServer
    private let fileURL = URL.temporaryDirectory.appending(path: "mpv-remote-frame-\(getpid()).jpg")
    private var scheduled: Task<Void, Never>?
    private var isCapturing = false
    private var captureAgain = false
    /// Bumped whenever the file changes, so a frame from the old one that
    /// arrives late is dropped.
    private var generation = 0
    private var wasPaused = true

    /// How often a playing video's frame is refreshed.
    private static let interval: Duration = .seconds(20)
    /// Longest side of the frame sent to phones, in pixels: sharp on a phone's
    /// artwork, and about 80 KB, so it arrives in a moment.
    nonisolated private static let maxPixelSize = 960

    /// Saves the frame on screen to a file as an image, then reports whether
    /// that worked. mpv's own screenshot-to-file unless replaced: that needs
    /// FFmpeg's image encoders, which MPV Player Tiger Version's FFmpeg is
    /// built without, so the app saves the frame itself.
    var saveFrame: (URL, @escaping (Bool) -> Void) -> Void

    init(mpv: MPVConnection, server: RemoteServer) {
        self.mpv = mpv
        self.server = server
        saveFrame = { url, completion in mpv.saveFrame(to: url, completion: completion) }
    }

    func handle(event: String) {
        switch event {
        case "start-file", "end-file":
            clear()
        case "playback-restart":
            // A file opened or a seek landed. The very first frames are often
            // black or still settling, so give it a moment.
            capture(after: .seconds(1))
        default:
            break
        }
    }

    func stateChanged(_ state: PlayerState) {
        if !state.isRunning || state.isIdle {
            clear()
        } else if state.isPaused && !wasPaused {
            capture(after: .zero)
        } else if !state.isPaused && wasPaused {
            capture(after: Self.interval)
        }
        wasPaused = state.isPaused
    }

    func phoneConnected() {
        capture(after: .zero)
    }

    private func clear() {
        scheduled?.cancel()
        generation += 1
        server.updateThumbnail(nil)
    }

    private func capture(after delay: Duration) {
        scheduled?.cancel()
        scheduled = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.captureNow()
        }
    }

    private func captureNow() {
        guard server.hasPhones, mpv.state.isRunning, !mpv.state.isIdle else { return }
        guard !isCapturing else {
            captureAgain = true
            return
        }
        isCapturing = true
        let generation = generation
        let url = fileURL
        saveFrame(url) { [weak self] saved in
            Task { [weak self] in
                let jpeg = saved ? await Task.detached { Self.shrink(url) }.value : nil
                try? FileManager.default.removeItem(at: url)
                guard let self else { return }
                isCapturing = false
                // A capture that failed, as it does with mpv minimized, keeps the last frame.
                if let jpeg, generation == self.generation {
                    server.updateThumbnail(jpeg)
                }
                if captureAgain {
                    captureAgain = false
                    captureNow()
                } else if !mpv.state.isPaused {
                    capture(after: Self.interval)
                }
            }
        }
    }

    /// mpv saves the frame at the video's full size; phones need far less.
    nonisolated private static func shrink(_ url: URL) -> Data? {
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options)
        else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.7] as CFDictionary)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }
}
