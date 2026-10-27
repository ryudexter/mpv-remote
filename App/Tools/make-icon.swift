import AppKit

// Renders the icons of MPV Player Remote and MPV Player Tiger Version from one
// drawing, so the two stay a matching pair: the same striped tiger tile, with
// a remote on the iPhone app and a laptop on the Mac app.
//
//   swift make-icon.swift remote <AppIcon.png>
//   swift make-icon.swift laptop <AppIcon.appiconset>
//
// The iPhone icon is one opaque 1024×1024 square (App Store Connect rejects
// icons with an alpha channel, and iOS rounds the corners itself). The Mac icon
// draws its own rounded tile on a transparent canvas, inset as macOS icons are,
// at every size the asset catalog asks for.

enum Device: String { case remote, laptop }

let space = CGColorSpace(name: CGColorSpace.sRGB)!

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

let ink = rgb(0x1E1611)       // the stripes, and the device's screen and buttons
let cream = rgb(0xFFF8F0)     // the device
let play = rgb(0xFF8A1F)      // the play button, the one mark both apps share

/// A path in the drawing's own units: a 200×200 tile, y pointing down.
func path(_ build: (CGMutablePath) -> Void) -> CGPath {
    let p = CGMutablePath()
    build(p)
    return p
}

/// The stripes on the left; the right side is their mirror image.
let stripes: [CGPath] = [
    path { p in
        p.move(to: CGPoint(x: -6, y: 24))
        p.addCurve(to: CGPoint(x: 48, y: 48), control1: CGPoint(x: 12, y: 24), control2: CGPoint(x: 30, y: 32))
        p.addCurve(to: CGPoint(x: -6, y: 44), control1: CGPoint(x: 30, y: 42), control2: CGPoint(x: 12, y: 42))
    },
    path { p in
        p.move(to: CGPoint(x: -6, y: 82))
        p.addCurve(to: CGPoint(x: 54, y: 100), control1: CGPoint(x: 16, y: 80), control2: CGPoint(x: 36, y: 86))
        p.addCurve(to: CGPoint(x: -6, y: 104), control1: CGPoint(x: 36, y: 96), control2: CGPoint(x: 16, y: 98))
    },
    path { p in
        p.move(to: CGPoint(x: -6, y: 110))
        p.addCurve(to: CGPoint(x: 40, y: 126), control1: CGPoint(x: 10, y: 110), control2: CGPoint(x: 26, y: 114))
        p.addCurve(to: CGPoint(x: -6, y: 122), control1: CGPoint(x: 24, y: 120), control2: CGPoint(x: 10, y: 120))
    },
    path { p in
        p.move(to: CGPoint(x: -6, y: 156))
        p.addCurve(to: CGPoint(x: 46, y: 166), control1: CGPoint(x: 10, y: 154), control2: CGPoint(x: 28, y: 156))
        p.addCurve(to: CGPoint(x: -6, y: 176), control1: CGPoint(x: 28, y: 166), control2: CGPoint(x: 10, y: 170))
    },
]

func roundedRect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> CGPath {
    CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerWidth: r, cornerHeight: r, transform: nil)
}

func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> CGPath {
    CGPath(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2), transform: nil)
}

/// A play triangle with its corners rounded by a stroke of the same colour.
func playButton(_ ctx: CGContext, left: CGFloat, top: CGFloat, bottom: CGFloat, tip: CGFloat) {
    ctx.addPath(path { p in
        p.move(to: CGPoint(x: left, y: top))
        p.addLine(to: CGPoint(x: left, y: bottom))
        p.addLine(to: CGPoint(x: tip, y: (top + bottom) / 2))
        p.closeSubpath()
    })
    ctx.setFillColor(play)
    ctx.setStrokeColor(play)
    ctx.setLineWidth(4)
    ctx.setLineJoin(.round)
    ctx.drawPath(using: .fillStroke)
}

/// Fills the device's outline in cream over a soft shadow on the tile.
/// Shadow offsets ignore the transform, so they're given in pixels.
func lifted(_ ctx: CGContext, scale k: CGFloat, _ outline: [CGPath]) {
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -6 * k), blur: 10 * k, color: rgb(0x8A3A00, 0.45))
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    ctx.setFillColor(cream)
    for shape in outline { ctx.addPath(shape); ctx.fillPath() }
    ctx.endTransparencyLayer()
    ctx.restoreGState()
}

func fill(_ ctx: CGContext, _ shape: CGPath, _ color: CGColor) {
    ctx.addPath(shape)
    ctx.setFillColor(color)
    ctx.fillPath()
}

/// The whole tile, square, in `rect` of a context whose y points up.
func drawTile(_ device: Device, in ctx: CGContext, rect: CGRect) {
    let k = rect.width / 200
    ctx.saveGState()
    ctx.translateBy(x: rect.minX, y: rect.maxY)
    ctx.scaleBy(x: k, y: -k)

    // Tiger orange, lighter at the top left.
    let orange = CGGradient(colorsSpace: space, colors: [rgb(0xFFA63D), rgb(0xEE6F10)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(orange, start: .zero, end: CGPoint(x: 200, y: 200),
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

    var mirror = CGAffineTransform(translationX: 200, y: 0).scaledBy(x: -1, y: 1)
    for stripe in stripes {
        fill(ctx, stripe, ink)
        fill(ctx, stripe.copy(using: &mirror)!, ink)
    }

    switch device {
    case .remote:
        lifted(ctx, scale: k, [roundedRect(74, 32, 52, 136, 26)])
        fill(ctx, circle(100, 74, 23), rgb(0xEDE0D1))
        fill(ctx, circle(100, 74, 18), ink)
        playButton(ctx, left: 95.5, top: 66, bottom: 82, tip: 109)
        for (x, y) in [(89.0, 114.0), (111, 114), (89, 136), (111, 136)] {
            fill(ctx, circle(x, y, 6.5), ink)
        }
    case .laptop:
        let base = path { p in
            p.move(to: CGPoint(x: 42, y: 130))
            p.addLine(to: CGPoint(x: 158, y: 130))
            p.addQuadCurve(to: CGPoint(x: 152, y: 140), control: CGPoint(x: 158, y: 136))
            p.addLine(to: CGPoint(x: 48, y: 140))
            p.addQuadCurve(to: CGPoint(x: 42, y: 130), control: CGPoint(x: 42, y: 136))
        }
        lifted(ctx, scale: k, [roundedRect(54, 58, 92, 66, 9), base])
        fill(ctx, roundedRect(61, 65, 78, 52, 4), ink)
        playButton(ctx, left: 95.5, top: 83, bottom: 99, tip: 109)
        fill(ctx, roundedRect(89, 130, 22, 3, 1.5), rgb(0xE2D3C2))
    }
    ctx.restoreGState()
}

func save(_ ctx: CGContext, to url: URL) {
    let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, ctx.makeImage()!, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("Couldn't write \(url.path)") }
}

let args = CommandLine.arguments
guard args.count == 3, let device = Device(rawValue: args[1]) else {
    print("usage: swift make-icon.swift remote <AppIcon.png> | laptop <AppIcon.appiconset>")
    exit(1)
}
let out = URL(fileURLWithPath: args[2])

switch device {
case .remote:
    let ctx = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0,
                        space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    drawTile(.remote, in: ctx, rect: CGRect(x: 0, y: 0, width: 1024, height: 1024))
    save(ctx, to: out)

case .laptop:
    // macOS's icon grid: an 824-point tile with rounded corners, centred on a
    // 1024 canvas, over a soft drop shadow.
    let sizes = [16, 32, 64, 128, 256, 512, 1024]
    try! FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    for size in sizes {
        let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let s = CGFloat(size) / 1024
        let tile = CGRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
        let shape = CGPath(roundedRect: tile, cornerWidth: 185 * s, cornerHeight: 185 * s, transform: nil)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -10 * s), blur: 24 * s, color: rgb(0x000000, 0.3))
        fill(ctx, shape, rgb(0xEE6F10))
        ctx.restoreGState()
        ctx.addPath(shape)
        ctx.clip()
        drawTile(.laptop, in: ctx, rect: tile)
        save(ctx, to: out.appendingPathComponent("mac-\(size).png"))
    }
    let slots = [(16, 1, 16), (16, 2, 32), (32, 1, 32), (32, 2, 64), (128, 1, 128),
                 (128, 2, 256), (256, 1, 256), (256, 2, 512), (512, 1, 512), (512, 2, 1024)]
    let images = slots.map { point, scale, pixels in
        "    { \"filename\" : \"mac-\(pixels).png\", \"idiom\" : \"mac\", \"scale\" : \"\(scale)x\", \"size\" : \"\(point)x\(point)\" }"
    }
    let contents = "{\n  \"images\" : [\n\(images.joined(separator: ",\n"))\n  ],\n  \"info\" : { \"author\" : \"xcode\", \"version\" : 1 }\n}\n"
    try! contents.write(to: out.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
}
