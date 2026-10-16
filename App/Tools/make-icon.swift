import AppKit

// Renders the 1024×1024 app icon straight into an opaque bitmap (App Store
// Connect rejects icons with an alpha channel).
let size = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

// Background: deep violet, lighter at the top left.
let background = CGGradient(colorsSpace: space, colors: [rgb(0x7A4FE0), rgb(0x2B1170)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(background, start: CGPoint(x: 0, y: CGFloat(size)), end: CGPoint(x: CGFloat(size), y: 0), options: [])

let center = CGPoint(x: 512, y: 512)
func disc(_ radius: CGFloat, _ color: CGColor) {
    ctx.setFillColor(color)
    ctx.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
}

// Soft shadow under the disc.
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 50, color: rgb(0x12052E, 0.55))
disc(250, rgb(0x241047))
ctx.restoreGState()

// Concentric rings with a play button, in the spirit of mpv's own mark.
disc(250, rgb(0x241047))
disc(206, rgb(0xA27BFF))
disc(168, rgb(0x5B2CC0))

let play = CGMutablePath()
let r: CGFloat = 92
play.move(to: CGPoint(x: center.x - r * 0.42, y: center.y + r * 0.72))
play.addLine(to: CGPoint(x: center.x + r * 0.82, y: center.y))
play.addLine(to: CGPoint(x: center.x - r * 0.42, y: center.y - r * 0.72))
play.closeSubpath()
ctx.addPath(play)
ctx.setLineJoin(.round)
ctx.setLineWidth(34)
ctx.setStrokeColor(rgb(0xF4EEFF))
ctx.setFillColor(rgb(0xF4EEFF))
ctx.drawPath(using: .fillStroke)

// Broadcast arcs either side: this one is the remote.
ctx.setLineCap(.round)
ctx.setStrokeColor(rgb(0xFFFFFF, 0.85))
for (radius, width) in [(318.0, 40.0), (392.0, 40.0)] as [(CGFloat, CGFloat)] {
    ctx.setLineWidth(width)
    for side in [0.0, CGFloat.pi] {
        ctx.addArc(center: center, radius: radius, startAngle: side - 0.52, endAngle: side + 0.52, clockwise: false)
        ctx.strokePath()
    }
}

let image = ctx.makeImage()!
let url = URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL
let destination = CGImageDestinationCreateWithURL(url, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(destination, image, nil)
CGImageDestinationFinalize(destination)
