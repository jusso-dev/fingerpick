import FingerPickKit
import Testing
import UIKit
@testable import FingerPick

struct PaletteTests {
    private func relativeLuminance(_ colour: UIColor) -> Double {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        colour.getRed(&r, green: &g, blue: &b, alpha: &a)
        func channel(_ c: CGFloat) -> Double {
            let c = Double(c)
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
    }

    private func contrast(_ a: UIColor, _ b: UIColor) -> Double {
        let la = relativeLuminance(a), lb = relativeLuminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    @Test(arguments: [UIUserInterfaceStyle.light, .dark])
    func everyPlayerColourHasThreeToOneContrast(style: UIUserInterfaceStyle) throws {
        let traits = UITraitCollection(userInterfaceStyle: style)
        let background = style == .dark ? UIColor.black : UIColor.white
        for index in 0..<PlayerMarker.paletteSize {
            let colour = try #require(UIColor(named: "Players/Player\(index)", in: .main, compatibleWith: traits))
            #expect(contrast(colour.resolvedColor(with: traits), background) >= 3, "Player\(index) in \(style.rawValue)")
        }
    }

    @Test func coloursAreDistinct() {
        let traits = UITraitCollection(userInterfaceStyle: .light)
        let colours = (0..<PlayerMarker.paletteSize).compactMap {
            UIColor(named: "Players/Player\($0)", in: .main, compatibleWith: traits)?.resolvedColor(with: traits)
        }
        #expect(Set(colours.map(\.description)).count == PlayerMarker.paletteSize)
    }

    @Test func namesCombineColourShapeAndNumber() {
        #expect(Palette.name(PlayerMarker(slot: 0)) == "Orange circle 1")
        #expect(Palette.name(PlayerMarker(slot: 11)) == "Sky blue square 12")
    }
}
