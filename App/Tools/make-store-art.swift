import AppKit

// Builds the App Store art from raw simulator screenshots (1320×2868, the
// 6.9-inch size) and the Watch screenshots (416×496, 46mm): captioned
// screenshots for large and medium iPhones, plus the creative assets — the
// product-page header, the search results art, and a Watch-led header to
// swap in or test against it.
//
//   swift make-store-art.swift <raw-dir> <watch-dir> <icon.png> <out-dir>
//
// Raw screenshots are expected as 1-picker … 6-chapters.png (see `shots`),
// Watch ones as 1-remote, 2-options and 3-subtitles.png.

let args = CommandLine.arguments
let rawDir = URL(fileURLWithPath: args[1])
let watchDir = URL(fileURLWithPath: args[2])
let icon = NSImage(contentsOf: URL(fileURLWithPath: args[3]))!
let outDir = URL(fileURLWithPath: args[4])

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
    NSGraphicsContext.current!.imageInterpolation = .high
    draw(CGRect(x: 0, y: 0, width: width, height: height))
    NSGraphicsContext.current = nil
    try! FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, ctx.makeImage()!, nil)
    CGImageDestinationFinalize(destination)
}

/// The tiger icon's orange, with text in the near-black of its stripes.
func backdrop(_ rect: CGRect, glowAt glow: CGPoint, glowRadius: CGFloat) {
    NSGradient(colors: [color(0xF7A03A), color(0xE0640F)])!.draw(in: rect, angle: -90)
    NSGradient(colors: [color(0xFFD27A, 0.45), color(0xFFD27A, 0)])!
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

/// A mask that's solid for its bottom quarter and fades out towards the top.
let fadeMask: CGImage = {
    let gray = CGColorSpaceCreateDeviceGray()
    let ctx = CGContext(data: nil, width: 1, height: 256, bitsPerComponent: 8, bytesPerRow: 0,
                        space: gray, bitmapInfo: CGImageAlphaInfo.none.rawValue)!
    let gradient = CGGradient(colorsSpace: gray, colors: [CGColor(gray: 1, alpha: 1), CGColor(gray: 1, alpha: 1),
                                                          CGColor(gray: 0, alpha: 1)] as CFArray, locations: [0, 0.25, 1])!
    ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: 256), options: [])
    return ctx.makeImage()!
}()

/// A Watch screenshot in a dark case with the Digital Crown and side button,
/// its band running off above and below and fading out.
func watch(_ screenshot: NSImage, in screen: CGRect) {
    let scale = screen.width / 416
    let display = screen.insetBy(dx: -22 * scale, dy: -22 * scale)
    let body = display.insetBy(dx: -18 * scale, dy: -18 * scale)
    let ctx = NSGraphicsContext.current!.cgContext

    let bandWidth = body.width * 0.76, bandLength = body.height * 0.6
    for up in [true, false] {
        let band = CGRect(x: body.midX - bandWidth / 2, y: body.maxY - 60 * scale, width: bandWidth, height: bandLength)
        ctx.saveGState()
        if !up {
            // The lower band is the upper one turned over the Watch's middle.
            ctx.translateBy(x: 0, y: 2 * body.midY)
            ctx.scaleBy(x: 1, y: -1)
        }
        ctx.clip(to: band, mask: fadeMask)
        NSGradient(colors: [color(0x16131A), color(0x2C2733), color(0x16131A)])!.draw(in: band, angle: 0)
        ctx.restoreGState()
    }

    // Crown and side button stick out of the right edge, so draw them first.
    let crown = CGRect(x: body.maxX - 12 * scale, y: body.maxY - body.height * 0.3 - 62 * scale, width: 36 * scale, height: 124 * scale)
    NSGradient(colors: [color(0x2A2A2E), color(0x5C5C63), color(0x2A2A2E)])!
        .draw(in: NSBezierPath(roundedRect: crown, xRadius: 12 * scale, yRadius: 12 * scale), angle: 90)
    color(0x000000, 0.35).setFill()
    for ridge in stride(from: crown.minY + 14 * scale, to: crown.maxY - 10 * scale, by: 12 * scale) {
        NSBezierPath(rect: CGRect(x: body.maxX, y: ridge, width: crown.maxX - body.maxX - 4 * scale, height: 3 * scale)).fill()
    }
    let button = CGRect(x: body.maxX - 12 * scale, y: body.maxY - body.height * 0.62 - 90 * scale, width: 22 * scale, height: 180 * scale)
    NSGradient(colors: [color(0x2A2A2E), color(0x4A4A50), color(0x2A2A2E)])!
        .draw(in: NSBezierPath(roundedRect: button, xRadius: 10 * scale, yRadius: 10 * scale), angle: 90)

    let caseShape = NSBezierPath(roundedRect: body, xRadius: 124 * scale, yRadius: 124 * scale)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = color(0x000000, 0.5)
    shadow.shadowBlurRadius = 70 * scale
    shadow.shadowOffset = NSSize(width: 0, height: -24 * scale)
    shadow.set()
    color(0x1C1C1F).setFill()
    caseShape.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(colors: [color(0x4C4C52), color(0x222225), color(0x3A3A3F)])!.draw(in: caseShape, angle: -60)
    color(0x6A6A72, 0.8).setStroke()
    let edge = NSBezierPath(roundedRect: body.insetBy(dx: 2 * scale, dy: 2 * scale), xRadius: 122 * scale, yRadius: 122 * scale)
    edge.lineWidth = 3 * scale
    edge.stroke()
    color(0x000000).setFill()
    NSBezierPath(roundedRect: display, xRadius: 100 * scale, yRadius: 100 * scale).fill()
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: screen, xRadius: 78 * scale, yRadius: 78 * scale).addClip()
    screenshot.draw(in: screen)
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

func wrist(_ name: String) -> NSImage {
    NSImage(contentsOf: watchDir.appending(path: "\(name).png"))!
}

/// The icon with a shadow, or the orange icon melts into the orange backdrop.
func appIcon(in rect: CGRect) {
    let shape = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.225, yRadius: rect.width * 0.225)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = color(0x5A2300, 0.45)
    shadow.shadowBlurRadius = rect.width * 0.12
    shadow.shadowOffset = NSSize(width: 0, height: -rect.width * 0.04)
    shadow.set()
    color(0xE0640F).setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.saveGraphicsState()
    shape.addClip()
    icon.draw(in: rect)
    NSGraphicsContext.restoreGraphicsState()
}

/// Icon, name and tagline stacked from `left`, centred on `midY`; `s` sets their size.
func brand(_ tagline: String, left: CGFloat, midY: CGFloat, size s: CGFloat) {
    let iconSize = s * 0.24
    let lines = CGFloat(tagline.split(separator: "\n").count)
    let blockHeight = iconSize + s * 0.04 + s * 0.11 + s * 0.065 * lines
    let iconRect = CGRect(x: left, y: midY + blockHeight / 2 - iconSize, width: iconSize, height: iconSize)
    appIcon(in: iconRect)
    let nameTop = iconRect.minY - s * 0.04
    text("MPV Player Remote", size: s * 0.085, weight: .bold, color: color(0x1E1712), alignment: .left,
         in: CGRect(x: left, y: nameTop - s * 0.11, width: s * 1.1, height: s * 0.11))
    text(tagline, size: s * 0.05, weight: .medium, color: color(0x1E1712, 0.78), alignment: .left,
         in: CGRect(x: left, y: nameTop - s * 0.11 - s * 0.065 * lines - s * 0.01, width: s * 1.1, height: s * 0.065 * lines + s * 0.01))
}

// MARK: Screenshots: large (6.9-inch) and medium (6.1/6.3-inch) iPhones

for (width, height) in [(1320, 2868), (1179, 2556)] {
    // Laid out for 1320 wide; everything scales by k for the smaller size.
    let k = CGFloat(width) / 1320
    let W = CGFloat(width), H = CGFloat(height)
    for (index, shot) in shots.enumerated() {
        let url = outDir.appending(path: "screenshots/\(width)x\(height)/\(index + 1)-\(shot.file.split(separator: "-").last!).png")
        render(width: width, height: height, to: url) { rect in
            backdrop(rect, glowAt: CGPoint(x: W / 2, y: H * 0.53), glowRadius: 1100 * k)
            let lines = CGFloat(shot.headline.split(separator: "\n").count)
            let headlineHeight = 118 * k * lines
            let headlineTop = H - 170 * k
            text(shot.headline, size: 104 * k, weight: .bold, color: color(0x1E1712), alignment: .center,
                 in: CGRect(x: 80 * k, y: headlineTop - headlineHeight, width: W - 160 * k, height: headlineHeight))
            text(shot.subline, size: 50 * k, weight: .medium, color: color(0x1E1712, 0.78), alignment: .center,
                 in: CGRect(x: 80 * k, y: headlineTop - headlineHeight - 100 * k, width: W - 160 * k, height: 70 * k))
            let phoneWidth = 1030 * k, phoneHeight = phoneWidth * 2868 / 1320
            let phoneTop = headlineTop - headlineHeight - 170 * k
            phone(raw(shot.file), in: CGRect(x: (W - phoneWidth) / 2, y: phoneTop - phoneHeight, width: phoneWidth, height: phoneHeight))
        }
    }
}

// MARK: Creative assets
//
// Each slot on the product page takes one asset, so the header and the search
// results get one each, and the Watch-led header waits in the asset library.
// iPhones crop about 8% off each side of the 21:9 header, and the back and
// share buttons sit over its top corners, so everything stays inside that.

/// One phone behind on the left, one in front, and the Watch beside it,
/// centred on `centerX` with the front phone `phoneHeight` tall.
func devices(behind: String, centerX: CGFloat, midY: CGFloat, phoneHeight: CGFloat) {
    let phoneWidth = phoneHeight * 1320 / 2868
    let back = phoneHeight * 0.86, backWidth = back * 1320 / 2868
    phone(raw(behind), in: CGRect(x: centerX - phoneWidth * 0.82 - backWidth / 2, y: midY - back / 2, width: backWidth, height: back))
    phone(raw("3-nowplaying"), in: CGRect(x: centerX - phoneWidth / 2, y: midY - phoneHeight / 2, width: phoneWidth, height: phoneHeight))
    let screenWidth = phoneWidth * 0.66, screenHeight = screenWidth * 496 / 416
    watch(wrist("1-remote"), in: CGRect(x: centerX + phoneWidth * 0.5 + phoneWidth * 0.13, y: midY - phoneHeight * 0.36,
                                        width: screenWidth, height: screenHeight))
}

render(width: 3840, height: 1646, to: outDir.appending(path: "creative-assets/header-3840x1646.png")) { rect in
    let W = rect.width, H = rect.height
    let centerX = W * 0.68
    backdrop(rect, glowAt: CGPoint(x: centerX, y: H / 2), glowRadius: H * 0.9)
    devices(behind: "5-queue", centerX: centerX, midY: H / 2, phoneHeight: H * 0.78)
    brand("Control mpv on your Mac\nfrom your iPhone and Apple Watch.", left: W * 0.12, midY: H / 2, size: H * 0.94)
}

render(width: 3840, height: 2560, to: outDir.appending(path: "creative-assets/search-3840x2560.png")) { rect in
    let W = rect.width, H = rect.height
    backdrop(rect, glowAt: CGPoint(x: W / 2, y: H * 0.4), glowRadius: H * 0.85)
    text("Your couch. Your controls.", size: 172, weight: .bold, color: color(0x1E1712), alignment: .center,
         in: CGRect(x: 0, y: H - 400, width: W, height: 210))
    text("Play, pause and skip from your iPhone or your wrist.", size: 84, weight: .medium, color: color(0x1E1712, 0.78),
         alignment: .center, in: CGRect(x: 0, y: H - 530, width: W, height: 110))
    devices(behind: "4-subtitles", centerX: W * 0.48, midY: (H - 640) / 2 + 40, phoneHeight: H * 0.68)
}

render(width: 3840, height: 1646, to: outDir.appending(path: "creative-assets/header-watch-3840x1646.png")) { rect in
    let W = rect.width, H = rect.height
    let centerX = W * 0.68
    backdrop(rect, glowAt: CGPoint(x: centerX, y: H / 2), glowRadius: H * 0.9)
    // Three Watches: the remote in front, its options either side.
    let screenWidth = H * 0.33, screenHeight = screenWidth * 496 / 416
    let side = screenWidth * 0.8, sideHeight = side * 496 / 416
    let spread = screenWidth * 1.1
    watch(wrist("2-options"), in: CGRect(x: centerX - spread - side / 2, y: H / 2 - sideHeight / 2, width: side, height: sideHeight))
    watch(wrist("3-subtitles"), in: CGRect(x: centerX + spread - side / 2, y: H / 2 - sideHeight / 2, width: side, height: sideHeight))
    watch(wrist("1-remote"), in: CGRect(x: centerX - screenWidth / 2, y: H / 2 - screenHeight / 2, width: screenWidth, height: screenHeight))
    brand("Now on Apple Watch.\nTap to pause, swipe to skip.", left: W * 0.12, midY: H / 2, size: H * 0.94)
}
