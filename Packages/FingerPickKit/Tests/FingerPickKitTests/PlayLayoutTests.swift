import CoreGraphics
import Testing
@testable import FingerPickKit

/// Point sizes used for geometry tests. iPhone Duo sizes assume @3x and are not confirmed by Apple:
/// outer 1398 x 2034 px -> 466 x 678 pt, inner 1878 x 2670 px -> 626 x 890 pt.
enum TestScreens {
    static let iPhoneSE = CGSize(width: 375, height: 667)
    static let iPhone17 = CGSize(width: 402, height: 874)
    static let iPhone17ProMax = CGSize(width: 440, height: 956)
    static let duoOuter = CGSize(width: 466, height: 678)
    static let duoInner = CGSize(width: 626, height: 890)
}

struct PlayLayoutTests {
    @Test(arguments: [TestScreens.iPhoneSE, TestScreens.iPhone17, TestScreens.iPhone17ProMax, TestScreens.duoOuter])
    func phonesAndDuoOuterAreCompact(size: CGSize) {
        let layout = PlayLayout(size: size)
        #expect(layout.canvas == .compact)
        #expect(layout.suggestedPlayers == 6)
        // Landscape too.
        #expect(PlayLayout(size: CGSize(width: size.height, height: size.width)).canvas == .compact)
    }

    @Test func duoInnerIsLarge() {
        let layout = PlayLayout(size: TestScreens.duoInner)
        #expect(layout.canvas == .large)
        #expect(layout.suggestedPlayers == 10)
        #expect(PlayLayout(size: CGSize(width: 890, height: 626)).canvas == .large)
    }

    @Test func regularWidthCountsAsLarge() {
        #expect(PlayLayout(size: TestScreens.duoOuter, isRegularWidth: true).canvas == .large)
    }

    @Test func ringDiameterScalesWithCanvasWithinLimits() {
        let sizes = [TestScreens.iPhoneSE, TestScreens.iPhone17, TestScreens.duoOuter, TestScreens.duoInner]
        let diameters = sizes.map { PlayLayout(size: $0).ringDiameter }
        #expect(diameters == diameters.sorted())
        #expect(diameters.allSatisfy { $0 >= 88 && $0 <= 150 })
        #expect(PlayLayout(size: CGSize(width: 100, height: 100)).ringDiameter == 88)
        #expect(PlayLayout(size: CGSize(width: 2000, height: 2000)).ringDiameter == 150)
    }

    @Test func ringDiameterIsPixelAligned() {
        let layout = PlayLayout(size: CGSize(width: 401, height: 800), displayScale: 3)
        #expect((layout.ringDiameter * 3).rounded() == layout.ringDiameter * 3)
    }

    /// Apple describes both Duo displays as sharing an aspect ratio. The published pixel sizes differ
    /// slightly (0.687 vs 0.703), so allow 3%. Layout is driven by size, so either way it scales.
    @Test func duoDisplaysScaleProportionally() {
        let outer = TestScreens.duoOuter, inner = TestScreens.duoInner
        #expect(abs(outer.width / outer.height - inner.width / inner.height) < 0.03)
        let outerRatio = PlayLayout(size: outer).ringDiameter / outer.width
        let innerRatio = PlayLayout(size: inner).ringDiameter / inner.width
        #expect(abs(outerRatio - innerRatio) < 0.02)
    }

    /// Each ring plus its badge needs about 1.2 x 1.5 diameters. The suggested player count must fit
    /// in a grid of those cells, in portrait and landscape.
    @Test(arguments: [TestScreens.iPhoneSE, TestScreens.iPhone17, TestScreens.iPhone17ProMax, TestScreens.duoOuter, TestScreens.duoInner])
    func suggestedPlayersFit(size: CGSize) {
        for size in [size, CGSize(width: size.height, height: size.width)] {
            let layout = PlayLayout(size: size)
            let d = layout.ringDiameter
            let cells = (size.width / (d * 1.2)).rounded(.down) * (size.height / (d * 1.5)).rounded(.down)
            #expect(Int(cells) >= layout.suggestedPlayers, "\(size)")
        }
    }

    @Test func layoutIsStableAcrossFoldCycles() {
        var sizes: [CGSize] = []
        for _ in 0..<20 { sizes += [TestScreens.duoOuter, TestScreens.duoInner] }
        let layouts = sizes.map { PlayLayout(size: $0) }
        #expect(Set(layouts.map(\.ringDiameter)).count == 2)
        #expect(layouts.first == PlayLayout(size: TestScreens.duoOuter))
        #expect(layouts.last == PlayLayout(size: TestScreens.duoInner))
    }

    // MARK: Occlusion (inner camera)

    private let camera = ReservedArea(kind: .occlusion, frame: CGRect(x: 520, y: 20, width: 60, height: 60), isActive: true)

    @Test func labelsMoveBelowActiveOcclusion() {
        let layout = PlayLayout(size: TestScreens.duoInner, reserved: [camera])
        #expect(layout.labelTop(from: 50, height: 40) == 88)
        // Not overlapping: unchanged.
        #expect(layout.labelTop(from: 200, height: 40) == 200)
    }

    @Test func inactiveOcclusionIsIgnored() {
        var inactive = camera
        inactive.isActive = false
        let layout = PlayLayout(size: TestScreens.duoInner, reserved: [inactive])
        #expect(layout.labelTop(from: 50, height: 40) == 50)
    }

    @Test func controlAvoidsOcclusionCorner() {
        let layout = PlayLayout(size: TestScreens.duoInner, reserved: [camera])
        let safe = CGRect(x: 0, y: 20, width: 626, height: 850)
        let corner = layout.controlCorner(controlSize: CGSize(width: 44, height: 44), safeFrame: safe)
        #expect(corner == .topLeading)
        let rect = layout.controlRect(corner, controlSize: CGSize(width: 44, height: 44), safeFrame: safe)
        #expect(!rect.intersects(camera.frame))
        let unobstructed = PlayLayout(size: TestScreens.duoInner)
        #expect(unobstructed.controlCorner(controlSize: CGSize(width: 44, height: 44), safeFrame: safe) == .topTrailing)
    }

    @Test func everyCornerBlockedFallsBackToTopTrailing() {
        let everything = ReservedArea(kind: .occlusion, frame: CGRect(x: 0, y: 0, width: 1000, height: 1000), isActive: true)
        let layout = PlayLayout(size: TestScreens.duoInner, reserved: [everything])
        let safe = CGRect(origin: .zero, size: TestScreens.duoInner)
        #expect(layout.controlCorner(controlSize: CGSize(width: 44, height: 44), safeFrame: safe) == .topTrailing)
        #expect(layout.controlRect(.bottomLeading, controlSize: CGSize(width: 44, height: 44), safeFrame: safe).minY == CGFloat(830))
    }
}
