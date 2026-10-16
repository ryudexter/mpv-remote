import AppKit

// Builds the App Store art from raw simulator screenshots (1320×2868, the
// 6.9-inch size): captioned screenshots, plus the wide product-page header.
//
//   swift make-store-art.swift <raw-dir> <icon.png> <out-dir>
//
// Raw screenshots are expected as 1-picker … 6-chapters.png (see `shots`).

let args = CommandLine.arguments
let rawDir = URL(fileURLWithPath: args[1])
let icon = NSImage(contentsOf: URL(fileURLWithPath: args[2]))!
let outDir = URL(fileURLWithPath: args[3])

let shots: [(file: String, headline: String, subline: String)] = [
    ("3-nowplaying", "Your couch.\nYour controls.", "Play, pause and seek mpv from your iPhone."),
    ("4-subtitles", "Subtitles, sorted.", "Switch tracks and fix the timing on the fly."),
    ("5-queue", "Jump to any episode.", "The whole playlist, one tap away."),
    ("6-chapters", "Skip to the good part.", "Every chapter, right where you want it."),
    ("2-pairing", "Set up in seconds.", "Finds your Mac on Wi-Fi. Pair once with a code."),
]

let space = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

/// Draws into an opaque bitmap — App Store Connect rejects alpha — and saves it as PNG.
func render(width: Int, height: Int, to url: URL, _ draw: (CGRect) -> Void) {
    let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                        space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    draw(CGRect(x: 0, y: 0, width: width, height: height))
    NSGraphicsContext.current = nil
    let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, ctx.makeImage()!, nil)
    CGImageDestinationFinalize(destination)
}

func backdrop(_ rect: CGRect, glowAt glow: CGPoint, glowRadius: CGFloat) {
    NSGradient(colors: [color(0x3A1A86), color(0x0E0620)])!.draw(in: rect, angle: -90)
    NSGradient(colors: [color(0x8B5CF6, 0.45), color(0x8B5CF6, 0)])!
        .draw(fromCenter: glow, radius: 0, toCenter: glow, radius: glowRadius, options: [])
}

/// A screenshot inside a dark bezel with rounded corners and a soft shadow.
func phone(_ screenshot: NSImage, in rect: CGRect) {
    let scale = rect.width / 1320
    let bezel = 22 * scale
    let corner = 170 * scale
    let outer = rect.insetBy(dx: -bezel, dy: -bezel)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = color(0x000000, 0.55)
    shadow.shadowBlurRadius = 90 * scale
    shadow.shadowOffset = NSSize(width: 0, height: -30 * scale)
    shadow.set()
    color(0x101012).setFill()
    NSBezierPath(roundedRect: outer, xRadius: corner + bezel, yRadius: corner + bezel).fill()
    NSGraphicsContext.restoreGraphicsState()
    color(0x3A3A40).setStroke()
    let edge = NSBezierPath(roundedRect: outer.insetBy(dx: 2 * scale, dy: 2 * scale), xRadius: corner + bezel, yRadius: corner + bezel)
    edge.lineWidth = 4 * scale
    edge.stroke()
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: rect, xRadius: corner, yRadius: corner).addClip()
    screenshot.draw(in: rect)
    NSGraphicsContext.restoreGraphicsState()
}

func text(_ string: String, size: CGFloat, weight: NSFont.Weight, color textColor: NSColor,
          alignment: NSTextAlignment, in rect: CGRect) {
    let style = NSMutableParagraphStyle()
    style.alignment = alignment
    style.lineHeightMultiple = 0.95
    NSAttributedString(string: string, attributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: textColor,
        .paragraphStyle: style,
    ]).draw(with: rect, options: [.usesLineFragmentOrigin])
}

func raw(_ name: String) -> NSImage {
    NSImage(contentsOf: rawDir.appending(path: "\(name).png"))!
}

// MARK: Screenshots, 1320×2868

for (index, shot) in shots.enumerated() {
    let url = outDir.appending(path: "screenshots/\(index + 1)-\(shot.file.split(separator: "-").last!).png")
    render(width: 1320, height: 2868, to: url) { rect in
        let phoneRect = CGRect(x: (1320 - 1030) / 2, y: 90, width: 1030, height: 1030 * 2868 / 1320)
        backdrop(rect, glowAt: CGPoint(x: phoneRect.midX, y: phoneRect.midY + 300), glowRadius: 1100)
        let lines = CGFloat(shot.headline.split(separator: "\n").count)
        let headlineTop: CGFloat = 2868 - 170
        text(shot.headline, size: 104, weight: .bold, color: .white, alignment: .center,
             in: CGRect(x: 80, y: headlineTop - 118 * lines, width: 1160, height: 118 * lines))
        text(shot.subline, size: 50, weight: .medium, color: color(0xCDBEFF, 0.9), alignment: .center,
             in: CGRect(x: 80, y: headlineTop - 118 * lines - 100, width: 1160, height: 70))
        phone(raw(shot.file), in: phoneRect.offsetBy(dx: 0, dy: -(phoneRect.maxY - (headlineTop - 118 * lines - 170))))
    }
}

// MARK: Header, in both supported sizes

for (width, height) in [(3840, 1646), (5244, 2950)] {
    let url = outDir.appending(path: "header/header-\(width)x\(height).png")
    render(width: width, height: height, to: url) { rect in
        let W = CGFloat(width), H = CGFloat(height)
        let phoneHeight = H * 0.8
        let phoneWidth = phoneHeight * 1320 / 2868
        let centerX = W * 0.70
        let y = (H - phoneHeight) / 2
        backdrop(rect, glowAt: CGPoint(x: centerX, y: H / 2), glowRadius: H * 0.9)

        // Two phones behind, one in front.
        let back = phoneHeight * 0.86, backWidth = back * 1320 / 2868
        let offset = phoneWidth * 0.82
        phone(raw("5-queue"), in: CGRect(x: centerX - offset - backWidth / 2, y: (H - back) / 2, width: backWidth, height: back))
        phone(raw("4-subtitles"), in: CGRect(x: centerX + offset - backWidth / 2, y: (H - back) / 2, width: backWidth, height: back))
        phone(raw("3-nowplaying"), in: CGRect(x: centerX - phoneWidth / 2, y: y, width: phoneWidth, height: phoneHeight))

        // Icon, name and tagline on the left, sized so they stay clear of the
        // phones in the taller 16:9 format too.
        let s = min(H, W * 0.43)
        let left = W * 0.07
        let iconSize = s * 0.24
        let blockHeight = iconSize + s * 0.05 + s * 0.1 + s * 0.12
        let top = H / 2 + blockHeight / 2
        let iconRect = CGRect(x: left, y: top - iconSize, width: iconSize, height: iconSize)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: iconRect, xRadius: iconSize * 0.225, yRadius: iconSize * 0.225).addClip()
        icon.draw(in: iconRect)
        NSGraphicsContext.restoreGraphicsState()
        let nameTop = iconRect.minY - s * 0.04
        text("MPV Player Remote", size: s * 0.085, weight: .bold, color: .white, alignment: .left,
             in: CGRect(x: left, y: nameTop - s * 0.11, width: W * 0.4, height: s * 0.11))
        text("Control mpv on your Mac\nfrom your iPhone.", size: s * 0.05, weight: .medium, color: color(0xCDBEFF, 0.9),
             alignment: .left, in: CGRect(x: left, y: nameTop - s * 0.11 - s * 0.14, width: W * 0.4, height: s * 0.13))
    }
}
