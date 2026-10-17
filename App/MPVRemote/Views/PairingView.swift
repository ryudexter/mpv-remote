import SwiftUI

/// Asks for the 4-digit code the companion shows over the video in mpv.
struct PairingView: View {
    @Environment(RemoteController.self) private var remote
    @State private var code = ""
    @State private var attempts = 0
    @FocusState private var isFocused: Bool

    private let length = 4

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Image(systemName: "laptopcomputer.and.iphone")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                    .symbolRenderingMode(.hierarchical)

                VStack(spacing: 8) {
                    Text("Enter Pairing Code")
                        .font(.title2.bold())
                    Text("Type the code that appears over the video in mpv on \(remote.computer?.name ?? "your computer").")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }

                codeField
                    .modifier(Shake(animatableData: CGFloat(attempts)))

                Text(remote.pairingFailed ? "That code didn't match. Try again." : " ")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
            .padding(32)
            .frame(maxHeight: .infinity, alignment: .top)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { remote.forgetComputer() }
                }
            }
        }
        .interactiveDismissDisabled()
        .onAppear { isFocused = true }
        .onChange(of: code) { _, newValue in
            let digits = String(newValue.filter(\.isNumber).prefix(length))
            if digits != newValue { code = digits }
            if digits.count == length { remote.pair(code: digits) }
        }
        .onChange(of: remote.pairingFailed) { _, failed in
            guard failed else { return }
            withAnimation(.default) { attempts += 1 }
            code = ""
        }
    }

    /// A real text field, invisible, under four boxes that show its digits.
    private var codeField: some View {
        ZStack {
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isFocused)
                .foregroundStyle(.clear)
                .tint(.clear)
            HStack(spacing: 12) {
                ForEach(0..<length, id: \.self) { index in
                    let digit = index < code.count ? String(Array(code)[index]) : ""
                    Text(digit)
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .frame(width: 58, height: 70)
                        .background(.fill.tertiary, in: .rect(cornerRadius: 14))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(index == code.count && isFocused ? Color.accentColor : .clear, lineWidth: 2)
                        }
                }
            }
            .allowsHitTesting(false)
        }
        .frame(height: 70)
        .contentShape(.rect)
        .onTapGesture { isFocused = true }
    }
}

private struct Shake: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 10 * sin(animatableData * .pi * 4), y: 0))
    }
}
