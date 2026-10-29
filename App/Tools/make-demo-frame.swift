import AppKit
import CoreImage

// Draws the frame the App Store screenshots show in the artwork: a made-up
// still for the demo's "The Northern Lights", an aurora over a fjord. It is
// saved as the companion sends frames, a 960 px JPEG.
//
//   swift make-demo-frame.swift <out.jpg>

let W = 1920, H = 1080
let horizon: CGFloat = 360
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ci = CIContext(options: [.workingColorSpace: space])

func context() -> CGContext {
    CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0, space: space,
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

struct RNG {
    var s: UInt64
    mutating func next() -> CGFloat {
        s = s &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat(Double(s >> 11) / Double(UInt64(1) << 53))
    }
}
var rng = RNG(s: 20261028)

func clamp(_ v: CGFloat) -> CGFloat { min(max(v, 0), 1) }

// MARK: Sky and stars

let sky = context()
let skyGradient = CGGradient(colorsSpace: space, colors: [rgb(0x15505A), rgb(0x0A2A3A), rgb(0x061226), rgb(0x030616)] as CFArray,
                             locations: [0, 0.18, 0.55, 1])!
sky.drawLinearGradient(skyGradient, start: CGPoint(x: 0, y: horizon), end: CGPoint(x: 0, y: CGFloat(H)), options: [.drawsBeforeStartLocation])
for _ in 0..<900 {
    let x = rng.next() * CGFloat(W), y = horizon + 80 + rng.next() * (CGFloat(H) - horizon - 80)
    let r = 0.5 + pow(rng.next(), 4) * 1.6
    sky.setFillColor(rgb(0xEAF2FF, 0.25 + rng.next() * 0.7))
    sky.fillEllipse(in: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
}

// MARK: Aurora: curtains of vertical rays

struct Curtain {
    var base: (CGFloat) -> CGFloat
    var height: (CGFloat) -> CGFloat
    var envelope: (CGFloat) -> CGFloat
    var low: UInt32, mid: UInt32, high: UInt32
    var strength: CGFloat
}

let curtains = [
    // The main ribbon, dipping towards the end of the fjord.
    Curtain(base: { x in horizon + 175 + 300 * pow((x - 1080) / 1150, 2) + 38 * sin(x / 150 + 0.7) + 18 * sin(x / 53) },
            height: { x in 380 + 110 * sin(x / 230 + 1.4) + 40 * sin(x / 71) },
            envelope: { x in clamp(1.25 - pow((x - 1000) / 1050, 2)) },
            low: 0xD8FFE8, mid: 0x34F2A2, high: 0x9A5CFF, strength: 1.0),
    // A fainter one above it, more violet.
    Curtain(base: { x in horizon + 470 + 60 * sin(x / 240 + 2) - 0.1 * (x - 960) + 22 * sin(x / 61) },
            height: { x in 280 + 80 * sin(x / 180 + 0.3) },
            envelope: { x in clamp(1 - pow((x - 760) / 820, 2)) },
            low: 0xC0FFEC, mid: 0x3BE0B0, high: 0xC86BFF, strength: 0.6),
]

let aurora = context()
aurora.setBlendMode(.plusLighter)
for curtain in curtains {
    for xi in 0..<W {
        let x = CGFloat(xi)
        let rays = 0.55 + 0.25 * sin(x / 19 + 1.7) * sin(x / 6.1) + 0.2 * sin(x / 43 + 0.4)
        let a = clamp(rays) * curtain.envelope(x) * curtain.strength
        guard a > 0.01 else { continue }
        let y0 = curtain.base(x), h = curtain.height(x)
        let g = CGGradient(colorsSpace: space,
                           colors: [rgb(curtain.low, 0), rgb(curtain.low, a), rgb(curtain.mid, a * 0.85),
                                    rgb(curtain.mid, a * 0.45), rgb(curtain.high, a * 0.3), rgb(curtain.high, 0)] as CFArray,
                           locations: [0, 0.015, 0.1, 0.4, 0.72, 1])!
        aurora.saveGState()
        aurora.clip(to: CGRect(x: x, y: y0 - 6, width: 1, height: h + 6))
        aurora.drawLinearGradient(g, start: CGPoint(x: x, y: y0 - 6), end: CGPoint(x: x, y: y0 + h), options: [])
        aurora.restoreGState()
    }
    // The bright lower edge that makes it read as a ribbon.
    for xi in stride(from: 0, to: W, by: 2) {
        let x = CGFloat(xi), e = curtain.envelope(x) * curtain.strength
        guard e > 0.02 else { continue }
        aurora.setStrokeColor(rgb(curtain.low, 0.4 * e))
        aurora.setLineWidth(3)
        aurora.move(to: CGPoint(x: x, y: curtain.base(x)))
        aurora.addLine(to: CGPoint(x: x + 2, y: curtain.base(x + 2)))
        aurora.strokePath()
    }
}

let auroraImage = CIImage(cgImage: aurora.makeImage()!)
let soft = auroraImage.applyingGaussianBlur(sigma: 1.4).cropped(to: auroraImage.extent)
let glow = auroraImage.applyingGaussianBlur(sigma: 28).cropped(to: auroraImage.extent)
    .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 1.2, kCIInputBrightnessKey: 0])
var scene = CIImage(cgImage: sky.makeImage()!)
scene = soft.applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: scene])
scene = glow.applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: scene])

// MARK: Mountains

/// A jagged ridge between two points, by midpoint displacement.
func ridge(from a: CGPoint, to b: CGPoint, roughness: CGFloat, depth: Int) -> [CGPoint] {
    var points = [a, b]
    var spread = roughness
    for _ in 0..<depth {
        var next: [CGPoint] = []
        for i in 0..<(points.count - 1) {
            let p = points[i], q = points[i + 1]
            next.append(p)
            next.append(CGPoint(x: (p.x + q.x) / 2 + (rng.next() - 0.5) * spread * 0.3,
                                y: (p.y + q.y) / 2 + (rng.next() - 0.5) * spread))
        }
        next.append(points.last!)
        points = next
        spread *= 0.55
    }
    return points
}

func fill(_ ctx: CGContext, ridge points: [CGPoint], down floor: CGFloat, color: CGColor, rim: CGColor? = nil) {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: points[0].x, y: floor))
    points.forEach { path.addLine(to: $0) }
    path.addLine(to: CGPoint(x: points.last!.x, y: floor))
    path.closeSubpath()
    ctx.addPath(path)
    ctx.setFillColor(color)
    ctx.fillPath()
    if let rim {
        ctx.addPath({ let p = CGMutablePath(); p.addLines(between: points); return p }())
        ctx.setStrokeColor(rim)
        ctx.setLineWidth(1.5)
        ctx.strokePath()
    }
}

let land = context()
// Far peaks at the end of the fjord, faintly lit by the aurora.
fill(land, ridge: ridge(from: CGPoint(x: 560, y: horizon + 30), to: CGPoint(x: 1420, y: horizon + 20), roughness: 120, depth: 7)
        .map { CGPoint(x: $0.x, y: max($0.y, horizon) + 40 * sin(($0.x - 560) / 860 * .pi)) },
     down: horizon - 2, color: rgb(0x0E2430), rim: rgb(0x3FBF96, 0.35))
// Middle slopes.
fill(land, ridge: ridge(from: CGPoint(x: 300, y: horizon + 150), to: CGPoint(x: 900, y: horizon + 6), roughness: 90, depth: 7),
     down: horizon - 2, color: rgb(0x08151E), rim: rgb(0x2E9C7C, 0.25))
fill(land, ridge: ridge(from: CGPoint(x: 1050, y: horizon + 10), to: CGPoint(x: 1700, y: horizon + 170), roughness: 90, depth: 7),
     down: horizon - 2, color: rgb(0x08151E), rim: rgb(0x2E9C7C, 0.25))
// The fjord's steep walls, closest and darkest.
fill(land, ridge: [CGPoint(x: -10, y: horizon + 560)] + ridge(from: CGPoint(x: 0, y: horizon + 540), to: CGPoint(x: 700, y: horizon), roughness: 150, depth: 8),
     down: horizon - 2, color: rgb(0x03070B), rim: rgb(0x1E6E5A, 0.3))
fill(land, ridge: ridge(from: CGPoint(x: 1260, y: horizon), to: CGPoint(x: 1930, y: horizon + 470), roughness: 150, depth: 8),
     down: horizon - 2, color: rgb(0x03070B), rim: rgb(0x1E6E5A, 0.3))

scene = CIImage(cgImage: land.makeImage()!).composited(over: scene)

// MARK: Water: the scene mirrored, darker and smeared sideways

let above = scene.cropped(to: CGRect(x: 0, y: horizon, width: CGFloat(W), height: CGFloat(H) - horizon))
let mirrored = above.transformed(by: CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: 2 * horizon)).clampedToExtent()
    .applyingFilter("CIMotionBlur", parameters: [kCIInputRadiusKey: 14, kCIInputAngleKey: 0])
    .applyingFilter("CIColorMatrix", parameters: [
        "inputRVector": CIVector(x: 0.5, y: 0, z: 0, w: 0), "inputGVector": CIVector(x: 0, y: 0.55, z: 0, w: 0),
        "inputBVector": CIVector(x: 0, y: 0, z: 0.6, w: 0), "inputBiasVector": CIVector(x: 0.004, y: 0.008, z: 0.016, w: 0),
    ])
    .cropped(to: CGRect(x: 0, y: 0, width: CGFloat(W), height: horizon))
scene = above.composited(over: mirrored)

let finish = context()
finish.draw(ci.createCGImage(scene, from: CGRect(x: 0, y: 0, width: W, height: H))!, in: CGRect(x: 0, y: 0, width: W, height: H))
// Ripples catching the light, and the water darkening towards us.
for _ in 0..<420 {
    let y = pow(rng.next(), 1.6) * (horizon - 8)
    let x = rng.next() * CGFloat(W), length = 20 + rng.next() * 160 * (1 - y / horizon)
    finish.setFillColor(rng.next() < 0.6 ? rgb(0x000000, 0.35) : rgb(0x8FFFD2, 0.06 + 0.06 * y / horizon))
    finish.fill(CGRect(x: x, y: y, width: length, height: 1 + rng.next() * 1.5))
}
let shade = CGGradient(colorsSpace: space, colors: [rgb(0x000000, 0.65), rgb(0x000000, 0)] as CFArray, locations: [0, 1])!
finish.drawLinearGradient(shade, start: .zero, end: CGPoint(x: 0, y: horizon), options: [])

var out = CIImage(cgImage: finish.makeImage()!)
out = out.applyingFilter("CIVignette", parameters: [kCIInputIntensityKey: 0.45, kCIInputRadiusKey: 1.8])
out = out.cropped(to: CGRect(x: 0, y: 0, width: W, height: H))

out = out.applyingFilter("CILanczosScaleTransform", parameters: [kCIInputScaleKey: 0.5])
let url = URL(fileURLWithPath: CommandLine.arguments[1])
try! ci.writeJPEGRepresentation(of: out, to: url, colorSpace: space,
                                options: [CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String): 0.7])
