// Draws the launch screen logo (the winner's mark from the app icon) as vector PDFs, light and dark.
// The splash (FingerPick/Launch/SplashView.swift) starts on this exact frame, so keep the size and
// geometry in step with LogoMark.swift.
// Usage: swift scripts/make-launch-logo.swift <LaunchLogo.imageset directory>
import CoreGraphics
import Foundation

/// LogoMark.launchSize, in points.
let size: CGFloat = 240
let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")

func colour(_ hex: UInt32) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255, alpha: 1
    )
}

/// The winner: a filled circle with a ring round it, in Player0 orange.
func render(_ hex: UInt32, name: String) {
    var box = CGRect(x: 0, y: 0, width: size, height: size)
    let ctx = CGContext(out.appendingPathComponent(name) as CFURL, mediaBox: &box, nil)!
    ctx.beginPDFPage(nil)
    let centre = CGPoint(x: size / 2, y: size / 2)
    let inner = size * 0.135, outer = size * 0.185
    ctx.setFillColor(colour(hex))
    ctx.fillEllipse(in: CGRect(x: centre.x - inner, y: centre.y - inner, width: inner * 2, height: inner * 2))
    ctx.setStrokeColor(colour(hex))
    ctx.setLineWidth(size * 0.025)
    ctx.strokeEllipse(in: CGRect(x: centre.x - outer, y: centre.y - outer, width: outer * 2, height: outer * 2))
    ctx.endPDFPage()
    ctx.closePDF()
}

// Players/Player0 light and dark.
render(0xC77800, name: "LaunchLogo.pdf")
render(0xE69F00, name: "LaunchLogo-Dark.pdf")
print("Wrote launch logo to \(out.path)")
