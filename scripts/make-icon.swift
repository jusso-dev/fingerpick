// Draws the FingerPick app icon variants (1024 x 1024) with CoreGraphics.
// Usage: swift scripts/make-icon.swift <output directory>
import AppKit
import CoreGraphics

let size = 1024
let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")

func colour(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255, alpha: alpha
    )
}

enum Variant { case light, dark, tinted }

/// Five fingers round a table: four player rings and the winner, drawn larger and filled.
func draw(_ variant: Variant, in ctx: CGContext) {
    let s = CGFloat(size)
    switch variant {
    case .light:
        let gradient = CGGradient(
            colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
            colors: [colour(0xF2A31B), colour(0xD55E00)] as CFArray, locations: [0, 1]
        )!
        ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: s), end: CGPoint(x: s, y: 0), options: [])
    case .dark, .tinted:
        // Transparent: the system supplies the dark or tinted background.
        break
    }

    let centre = CGPoint(x: s / 2, y: s / 2)
    let orbit = s * 0.33
    // Okabe-Ito colours for the dark variant; white or grey otherwise.
    let ringColours: [UInt32] = [0x56B4E9, 0x009E73, 0xF0E442, 0xCC79A7]
    for index in 0..<4 {
        let angle = CGFloat.pi / 4 + CGFloat(index) * .pi / 2
        let point = CGPoint(x: centre.x + cos(angle) * orbit, y: centre.y + sin(angle) * orbit)
        let radius = s * 0.085
        let stroke: CGColor = switch variant {
        case .light: colour(0xFFFFFF, 0.85)
        case .dark: colour(ringColours[index])
        case .tinted: colour(0xFFFFFF, 0.55)
        }
        ctx.setStrokeColor(stroke)
        ctx.setLineWidth(s * 0.03)
        ctx.strokeEllipse(in: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
    }

    // The winner: a filled circle with a ring round it.
    let winner: CGColor = switch variant {
    case .light: colour(0xFFFFFF)
    case .dark: colour(0xE69F00)
    case .tinted: colour(0xFFFFFF)
    }
    let inner = s * 0.135, outer = s * 0.185
    ctx.setFillColor(winner)
    ctx.fillEllipse(in: CGRect(x: centre.x - inner, y: centre.y - inner, width: inner * 2, height: inner * 2))
    ctx.setStrokeColor(winner)
    ctx.setLineWidth(s * 0.025)
    ctx.strokeEllipse(in: CGRect(x: centre.x - outer, y: centre.y - outer, width: outer * 2, height: outer * 2))
}

func render(_ variant: Variant, name: String) throws {
    // The light (default) icon must be opaque for the App Store, so it has no alpha channel.
    let alpha: CGImageAlphaInfo = variant == .light ? .noneSkipLast : .premultipliedLast
    let ctx = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: alpha.rawValue
    )!
    draw(variant, in: ctx)
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    let data = rep.representation(using: .png, properties: [:])!
    try data.write(to: out.appendingPathComponent(name))
}

try render(.light, name: "AppIcon.png")
try render(.dark, name: "AppIcon-Dark.png")
try render(.tinted, name: "AppIcon-Tinted.png")
print("Wrote icons to \(out.path)")
