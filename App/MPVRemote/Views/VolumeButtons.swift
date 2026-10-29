import AVFoundation
import MediaPlayer
import SwiftUI

enum VolumeButton {
    case up, down
}

extension View {
    /// Calls `action` when the iPhone's volume up or down button is pressed,
    /// in place of the buttons changing the phone's own volume.
    ///
    /// Never on a Mac, which has no such buttons: there iOS reports the volume
    /// as full whatever the Mac's is, and the catcher unmuted the Mac and
    /// turned it up nearly all the way each time the app came to the front,
    /// and all the way each time it went to the back.
    func onVolumeButtons(isEnabled: Bool, perform action: @escaping (VolumeButton) -> Void) -> some View {
        background {
            if !ProcessInfo.processInfo.isiOSAppOnMac {
                VolumeButtonCatcher(isEnabled: isEnabled, onPress: action)
                    .frame(width: 1, height: 1)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }
}

/// iOS doesn't report the volume buttons themselves, only the phone's volume
/// changing. So while enabled, each change counts as a press and the phone's
/// volume is put straight back, which also keeps it off either end, where a
/// press would change nothing. The system volume view this hosts stops iOS
/// showing its own volume indicator for all of that.
private struct VolumeButtonCatcher: UIViewRepresentable {
    var isEnabled: Bool
    var onPress: (VolumeButton) -> Void

    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView()
        // Nearly invisible rather than hidden: hidden, it no longer stops the indicator.
        view.alpha = 0.01
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: MPVolumeView, context: Context) {
        context.coordinator.onPress = onPress
        context.coordinator.setEnabled(isEnabled, volumeView: view)
    }

    static func dismantleUIView(_ view: MPVolumeView, coordinator: Coordinator) {
        coordinator.setEnabled(false, volumeView: view)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        /// Switching the audio session on or off can keep the thread waiting,
        /// so it's done here, in order, rather than on the main thread.
        private static let sessionQueue = DispatchQueue(label: "VolumeButtons.session")

        var onPress: (VolumeButton) -> Void = { _ in }
        private var isEnabled = false
        private var observation: NSKeyValueObservation?
        private weak var volumeView: MPVolumeView?
        /// The phone's volume before the buttons were taken over, put back after.
        private var originalVolume: Float = 0.5
        /// Where the phone's volume is held while the buttons are taken over.
        private var restingVolume: Float = 0.5
        /// The phone's volume as last reported, which the next change is compared with.
        private var lastVolume: Float = 0.5
        /// Set while the phone's volume is on its way back to `restingVolume`.
        private var isResetting = false

        func setEnabled(_ enabled: Bool, volumeView: MPVolumeView) {
            guard enabled != isEnabled else { return }
            isEnabled = enabled
            if enabled {
                self.volumeView = volumeView
                Self.sessionQueue.async { [weak self] in
                    let session = AVAudioSession.sharedInstance()
                    do {
                        // Mixing with anything else playing, so this doesn't stop it.
                        try session.setCategory(.playback, options: .mixWithOthers)
                        try session.setActive(true)
                    } catch {
                        return
                    }
                    Task { @MainActor [self] in self?.startWatching() }
                }
            } else {
                if let observation {
                    observation.invalidate()
                    self.observation = nil
                    setPhoneVolume(originalVolume)
                }
                Self.sessionQueue.async {
                    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                }
            }
        }

        private func startWatching() {
            guard isEnabled, observation == nil else { return }
            let session = AVAudioSession.sharedInstance()
            originalVolume = session.outputVolume
            lastVolume = originalVolume
            // The nearest of iOS's 16 volume steps, short of either end.
            restingVolume = min(max((originalVolume * 16).rounded() / 16, 1 / 16), 15 / 16)
            // Reported on whichever thread changed it, hence the hop to the main actor.
            observation = session.observe(\.outputVolume, options: .new) { @Sendable [weak self] _, change in
                guard let volume = change.newValue else { return }
                Task { @MainActor [self] in self?.phoneVolumeChanged(to: volume) }
            }
            if originalVolume != restingVolume {
                isResetting = setPhoneVolume(restingVolume)
            }
        }

        private func phoneVolumeChanged(to volume: Float) {
            guard observation != nil else { return }
            defer { lastVolume = volume }
            // Putting the volume back is reported too, and isn't a press.
            if isResetting, abs(volume - restingVolume) < 0.01 {
                isResetting = false
                return
            }
            guard abs(volume - lastVolume) > 0.001 else { return }
            onPress(volume > lastVolume ? .up : .down)
            isResetting = setPhoneVolume(restingVolume)
        }

        /// Whether it could: without a volume slider, as in Simulator, it can't.
        @discardableResult
        private func setPhoneVolume(_ volume: Float) -> Bool {
            // Looked up each time, as the view only makes its slider once on screen.
            guard let slider = volumeView?.firstSubview(of: UISlider.self) else { return false }
            slider.value = volume
            return true
        }
    }
}

private extension UIView {
    func firstSubview<View: UIView>(of type: View.Type) -> View? {
        for subview in subviews {
            if let match = subview as? View ?? subview.firstSubview(of: type) { return match }
        }
        return nil
    }
}
