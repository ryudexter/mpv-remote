import SwiftUI

/// Shown while the app reaches for the computer: the play mark from the app
/// icon, breathing, with rings rippling out of it like a signal.
struct ConnectingView: View {
    var computerName: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let markSize: CGFloat = 112
    private let ringCount = 3
    /// Seconds a ring takes to travel out and fade.
    private let period = 2.4

    var body: some View {
        VStack(spacing: 0) {
            TimelineView(.animation(paused: reduceMotion)) { context in
                let time = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
                ZStack {
                    ForEach(0..<ringCount, id: \.self) { ring in
                        // Spaced evenly through the period; still, they sit at fixed steps.
                        let progress = reduceMotion
                            ? Double(ring + 1) / Double(ringCount + 1)
                            : (time / period + Double(ring) / Double(ringCount)).truncatingRemainder(dividingBy: 1)
                        Circle()
                            .stroke(Self.lavender, lineWidth: 3 - 2 * progress)
                            .scaleEffect(1 + 1.4 * progress)
                            .opacity(0.9 * (1 - progress))
                    }
                    mark(breath: sin(time * 2 * .pi / period))
                }
                .frame(width: markSize, height: markSize)
            }
            // Room for the rings, which grow to 2.4 times the mark.
            .padding(markSize * 0.7)

            VStack(spacing: 6) {
                Text("Connecting to")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(computerName)
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RadialGradient(colors: [Self.purple.opacity(0.35), .clear], center: .center, startRadius: 0, endRadius: 360)
                .ignoresSafeArea()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Connecting to \(computerName)")
    }

    /// The icon's disc: a dark rim, a lavender ring, a purple face and the play glyph.
    private func mark(breath: Double) -> some View {
        ZStack {
            Circle().fill(Self.rim)
            Circle().fill(Self.lavender).padding(markSize * 0.088)
            Circle().fill(Self.purple).padding(markSize * 0.164)
            Image(systemName: "play.fill")
                .font(.system(size: markSize * 0.3, weight: .bold))
                .foregroundStyle(Self.glyph)
                // The triangle's weight sits left of its frame's centre.
                .offset(x: markSize * 0.03)
        }
        .scaleEffect(1 + 0.025 * breath)
        .shadow(color: Self.purple.opacity(0.8), radius: 22 + 8 * breath)
    }

    // The app icon's colours (Tools/make-icon.swift).
    private static let rim = Color(hex: 0x241047)
    private static let lavender = Color(hex: 0xA27BFF)
    private static let purple = Color(hex: 0x5B2CC0)
    private static let glyph = Color(hex: 0xF4EEFF)
}

private extension Color {
    init(hex: UInt32) {
        self.init(red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}
