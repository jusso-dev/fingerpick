import FingerPickKit
import SwiftUI

/// Colour-blind-safe player palette (based on Okabe-Ito) plus a shape for every colour, so colour
/// is never the only cue. Light and dark variants live in Assets.xcassets/Players and give at least
/// 3:1 contrast against the background.
enum Palette {
    static func colour(_ marker: PlayerMarker) -> Color {
        Color("Players/Player\(marker.colourIndex)")
    }

    /// Black or white, whichever contrasts more with `colour`. The worse of the two is never below
    /// 4.58:1, so badge text on any player colour meets the 4.5:1 minimum in light and dark mode.
    static func text(on colour: Color, in environment: EnvironmentValues) -> Color {
        let resolved = colour.resolve(in: environment)
        let luminance = 0.2126 * Double(resolved.linearRed) + 0.7152 * Double(resolved.linearGreen)
            + 0.0722 * Double(resolved.linearBlue)
        return (luminance + 0.05) / 0.05 >= 1.05 / (luminance + 0.05) ? .black : .white
    }

    static func symbol(_ marker: PlayerMarker) -> String {
        symbols[marker.shapeIndex]
    }

    /// Spoken and shown name, for example "Orange triangle 3".
    static func name(_ marker: PlayerMarker) -> String {
        String(
            localized: "\(colourNames[marker.colourIndex]) \(shapeNames[marker.shapeIndex]) \(marker.number)",
            comment: "Player name: colour, shape, number. For example: Orange triangle 3"
        )
    }

    private static let symbols = [
        "circle.fill", "triangle.fill", "square.fill", "diamond.fill", "star.fill",
        "hexagon.fill", "pentagon.fill", "heart.fill", "seal.fill", "shield.fill",
    ]

    private static let colourNames: [String] = [
        String(localized: "Orange"), String(localized: "Sky blue"), String(localized: "Green"),
        String(localized: "Yellow"), String(localized: "Blue"), String(localized: "Red"),
        String(localized: "Purple"), String(localized: "Grey"), String(localized: "Pink"),
        String(localized: "Brown"),
    ]

    private static let shapeNames: [String] = [
        String(localized: "circle"), String(localized: "triangle"), String(localized: "square"),
        String(localized: "diamond"), String(localized: "star"), String(localized: "hexagon"),
        String(localized: "pentagon"), String(localized: "heart"), String(localized: "seal"),
        String(localized: "shield"),
    ]
}
