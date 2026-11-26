import SwiftUI
import UIKit

/// The tick that says the app has just connected to mpv on the computer (`RemoteController.connectedMoments`). A small
/// black pill comes out of the Dynamic Island, or the notch, as if the iPhone itself said so; the tick draws itself in
/// it, left to right, sparkles, and the pill goes back in: about a second and a half in all. Where there's neither (an
/// iPhone SE, an iPad), the pill drops in from the top edge and goes back up. The same tick as Cingle Remote's.
///
/// Pixel art made with Pixel Lab: the tick (`ConnectedTick`, 32 pixels square) and its sparkle, 7 frames at 16 a
/// second (`ConnectedTickSparkle0`–`6`, 72 pixels square), which have the same tick in their middle, pixel for pixel, so
/// the one follows the other without a jump. One pixel is one point, which keeps them sharp at 2x and 3x.
///
/// With Reduce Motion, the pill fades in with the tick already drawn, and fades out. Taps go through it, and VoiceOver
/// leaves it out: it shows what the screen already says.
struct ConnectedTick: View {
    @Environment(RemoteController.self) private var remote
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// From the moment it starts coming out until it's back in.
    @State private var isShowing = false
    @State private var isOut = false
    /// How many of the tick's columns of pixels are drawn, from the left: its short stroke, then its long one.
    @State private var drawnColumns = 0
    /// The sparkle's frame on screen, once the tick is drawn. Nil before and after.
    @State private var sparkleFrame: Int?
    @State private var showing: Task<Void, Never>?

    /// The tick's pixels run from column 4 to 27 of its 32.
    private static let tickColumns = 4...28
    private static let sparkleFrames = 7
    private static let sparkleFrameTime = Duration.milliseconds(63)

    var body: some View {
        // Inside the safe area, which it says the size of, around the island or the notch; what's in it then reaches
        // past it to the top of the screen, from which it's placed. (Made to ignore the safe area itself, it says none.)
        GeometryReader { proxy in
            let insets = proxy.safeAreaInsets
            let place = Placement(width: proxy.size.width + insets.leading + insets.trailing, topInset: insets.top)
            let isOpen = isOut || reduceMotion
            let pill = isOpen ? place.out : place.tucked
            let corner = isOpen ? place.outCorner : place.tuckedCorner
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(.black)
                    .overlay {
                        // An edge to see it by on Cingle's black, only where it's out of the island or the notch.
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .strokeBorder(rim(hiddenShare: place.hiddenHeight / place.out.height), lineWidth: 1)
                            .opacity(isOpen ? 1 : 0)
                    }
                    .frame(width: pill.width, height: pill.height)
                    .position(x: pill.midX, y: pill.midY)
                art
                    .scaleEffect(isOpen ? 1 : 0.4)
                    .opacity(isOpen ? 1 : 0)
                    .position(isOpen ? place.tick : place.tuckedTick)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .ignoresSafeArea()
            .opacity(isShowing ? 1 : 0)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: remote.connectedMoments) { show() }
    }

    /// The tick drawn so far, or the sparkle's frame, in the middle of the sparkle's square.
    private var art: some View {
        ZStack {
            if let sparkleFrame {
                Image("ConnectedTickSparkle\(sparkleFrame)")
                    .interpolation(.none)
            } else {
                Image("ConnectedTick")
                    .interpolation(.none)
                    .mask(alignment: .leading) {
                        Rectangle().frame(width: CGFloat(drawnColumns))
                    }
            }
        }
        .frame(width: 72, height: 72)
    }

    /// Clear over the part of the pill in the island or the notch, so no outline shows around them.
    private func rim(hiddenShare: CGFloat) -> LinearGradient {
        let hidden = min(max(hiddenShare, 0), 0.9)
        return LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .clear, location: hidden),
                .init(color: .white.opacity(0.18), location: min(1, hidden + 0.1)),
                .init(color: .white.opacity(0.1), location: 1),
            ],
            startPoint: .top, endPoint: .bottom)
    }

    private func show() {
        showing?.cancel()
        showing = Task {
            sparkleFrame = nil
            drawnColumns = reduceMotion ? 32 : 0
            isShowing = true
            if reduceMotion {
                withAnimation(.easeOut(duration: 0.2)) { isOut = true }
                guard await pause(.milliseconds(1300)) else { return }
                withAnimation(.easeIn(duration: 0.2)) { isShowing = false }
                isOut = false
                return
            }
            withAnimation(.spring(duration: 0.45, bounce: 0.35)) { isOut = true }
            guard await pause(.milliseconds(170)) else { return }
            // Two columns at a time, a pixel art step, about a quarter of a second for the whole tick.
            for column in stride(from: Self.tickColumns.lowerBound, through: Self.tickColumns.upperBound, by: 2) {
                drawnColumns = column
                guard await pause(.milliseconds(20)) else { return }
            }
            drawnColumns = 32
            for frame in 0..<Self.sparkleFrames {
                sparkleFrame = frame
                guard await pause(Self.sparkleFrameTime) else { return }
            }
            sparkleFrame = nil
            guard await pause(.milliseconds(250)) else { return }
            // Back in, quicker than it came out.
            withAnimation(.spring(duration: 0.3, bounce: 0)) { isOut = false }
            guard await pause(.milliseconds(300)) else { return }
            isShowing = false
        }
    }

    /// Whether the time went by, rather than a newer connection starting the tick over.
    private func pause(_ time: Duration) async -> Bool {
        do {
            try await Task.sleep(for: time)
            return true
        } catch {
            return false
        }
    }
}

/// Where the pill is, tucked away and out, in the window's points.
private struct Placement {
    var tucked: CGRect
    var out: CGRect
    var tuckedCorner: CGFloat
    var outCorner: CGFloat
    /// How much of the pill, from its top, is in the island or the notch when it's out.
    var hiddenHeight: CGFloat
    /// The middle of the tick, out: in the part of the pill under the island or the notch.
    var tick: CGPoint
    var tuckedTick: CGPoint

    init(width: CGFloat, topInset: CGFloat) {
        // On whole points, so the pixel art's pixels stay even.
        let middle = (width / 2).rounded()
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
        if isPhone, topInset >= 51 {
            // The Dynamic Island: 126 by 37 points, its top 48 points above where the safe area starts (11 points from
            // the top of the screen on an iPhone 15, 14 on an iPhone 17). The pill starts inside it, out of sight.
            let island = CGRect(x: middle - 63, y: topInset - 48, width: 126, height: 37)
            tucked = island.insetBy(dx: 8, dy: 4)
            tuckedCorner = tucked.height / 2
            // Only so far down, so what's under it stays readable.
            out = CGRect(x: middle - 68, y: island.minY, width: 136, height: island.height + 36)
            outCorner = 24
            hiddenHeight = island.height
            tick = CGPoint(x: middle, y: (island.maxY + 18).rounded())
            tuckedTick = CGPoint(x: middle, y: island.midY.rounded())
        } else if isPhone, topInset >= 40 {
            // A notch, from the top edge to about 15 points above where the safe area starts, and at least 160 points
            // wide. The pill's top is above the screen, so only its round bottom shows.
            let notchBottom = topInset - 15
            tucked = CGRect(x: middle - 60, y: -30, width: 120, height: 30 + notchBottom - 6)
            tuckedCorner = 14
            out = CGRect(x: middle - 68, y: -30, width: 136, height: 30 + notchBottom + 44)
            outCorner = 24
            hiddenHeight = 30 + notchBottom
            tick = CGPoint(x: middle, y: (notchBottom + 22).rounded())
            tuckedTick = CGPoint(x: middle, y: (notchBottom / 2).rounded())
        } else {
            // Neither: a pill that drops from above the top edge to just under the status bar.
            out = CGRect(x: middle - 32, y: topInset + 6, width: 64, height: 44)
            tucked = out.offsetBy(dx: 0, dy: -(out.maxY + 10))
            tuckedCorner = 22
            outCorner = 22
            hiddenHeight = 0
            tick = CGPoint(x: middle, y: out.midY)
            tuckedTick = CGPoint(x: middle, y: tucked.midY)
        }
    }
}

/// Puts `ConnectedTick` in a window of its own over the app's, in the same scene: over its sheets too (the pairing sheet
/// closes as the computer accepts the code), and placed by the top of the screen. Taps go through it to the app.
struct ConnectedTickWindow: UIViewRepresentable {
    let remote: RemoteController

    func makeUIView(context: Context) -> Anchor { Anchor(remote: remote) }
    func updateUIView(_ anchor: Anchor, context: Context) {}

    final class Anchor: UIView {
        private let remote: RemoteController
        private var overlay: UIWindow?

        init(remote: RemoteController) {
            self.remote = remote
            super.init(frame: .zero)
            isUserInteractionEnabled = false
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard overlay == nil, let window, let scene = window.windowScene else { return }
            let overlay = PassThroughWindow(windowScene: scene)
            // Over the app's window and the sheets in it.
            overlay.windowLevel = .normal + 1
            let host = Host(rootView: AnyView(ConnectedTick().environment(remote)))
            host.app = window
            host.view.backgroundColor = .clear
            host.view.accessibilityElementsHidden = true
            overlay.rootViewController = host
            overlay.isHidden = false
            self.overlay = overlay
        }
    }

    private final class PassThroughWindow: UIWindow {
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { nil }
    }

    /// Leaves the status bar and the turning of the screen to the app's own window, under it.
    private final class Host: UIHostingController<AnyView> {
        weak var app: UIWindow?

        override var prefersStatusBarHidden: Bool { app?.rootViewController?.prefersStatusBarHidden ?? false }
        override var preferredStatusBarStyle: UIStatusBarStyle {
            app?.rootViewController?.preferredStatusBarStyle ?? .default
        }
        override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
            app?.rootViewController?.supportedInterfaceOrientations ?? .all
        }
    }
}
