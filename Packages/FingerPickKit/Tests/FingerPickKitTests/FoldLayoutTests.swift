import CoreGraphics
import Testing
@testable import FingerPickKit

/// Fake division regions for the iPhone Duo inner display (626 x 890 pt assumed).
struct FoldLayoutTests {
    private let size = TestScreens.duoInner
    /// Book posture: a vertical fold down the middle.
    private let bookFold = CGRect(x: 293, y: 0, width: 40, height: 890)
    /// Tabletop posture (rotated): a horizontal fold across the middle.
    private let tabletopFold = CGRect(x: 0, y: 425, width: 626, height: 40)

    private func layout(_ fold: CGRect, active: Bool = true, size: CGSize? = nil) -> PlayLayout {
        PlayLayout(size: size ?? self.size, reserved: [ReservedArea(kind: .division, frame: fold, isActive: active)])
    }

    @Test func flatFoldIsIgnored() {
        // Fully open: inactive with zero width.
        let flat = layout(CGRect(x: 313, y: 0, width: 0, height: 890), active: false)
        #expect(flat.activeDivisions.isEmpty)
        #expect(flat.revealRect == flat.bounds)
        #expect(flat.ringCentre(for: CGPoint(x: 313, y: 400)) == CGPoint(x: 313, y: 400))
    }

    @Test func inactiveRegionKeepsLayoutStable() {
        // Planning with the inactive region must not move anything until it activates.
        let inactive = layout(bookFold, active: false)
        #expect(inactive.revealRect == inactive.bounds)
        #expect(inactive.ringDiameter == PlayLayout(size: size).ringDiameter)
    }

    @Test func bookPostureRevealUsesLargerSide() {
        let rect = layout(bookFold).revealRect
        #expect(rect == CGRect(x: 0, y: 0, width: 293, height: 890))
        #expect(!rect.intersects(bookFold))

        let offCentre = layout(CGRect(x: 200, y: 0, width: 40, height: 890)).revealRect
        #expect(offCentre == CGRect(x: 240, y: 0, width: 386, height: 890))
    }

    @Test func tabletopPostureRevealUsesLargerSide() {
        let rect = layout(tabletopFold).revealRect
        #expect(rect == CGRect(x: 0, y: 0, width: 626, height: 425))
        #expect(!rect.intersects(tabletopFold))
        let lowFold = layout(CGRect(x: 0, y: 600, width: 626, height: 40)).revealRect
        #expect(lowFold.maxY == 600)
    }

    @Test(arguments: [CGPoint(x: 300, y: 400), CGPoint(x: 320, y: 100), CGPoint(x: 260, y: 800), CGPoint(x: 360, y: 10)])
    func ringsOnTheBookFoldAreNudgedClear(point: CGPoint) {
        let layout = layout(bookFold)
        let centre = layout.ringCentre(for: point)
        let radius = layout.ringDiameter / 2
        let ring = CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2)
        #expect(!ring.intersects(bookFold.insetBy(dx: 0.5, dy: 0.5)))
        #expect(centre.y == point.y)
        // Nudged towards the side the finger is on.
        #expect((centre.x < bookFold.midX) == (point.x < bookFold.midX))
    }

    @Test func ringsOnTheTabletopFoldAreNudgedClear() {
        let layout = layout(tabletopFold)
        let centre = layout.ringCentre(for: CGPoint(x: 100, y: 450))
        #expect(centre.x == 100)
        #expect(centre.y == tabletopFold.maxY + layout.ringDiameter / 2)
        let above = layout.ringCentre(for: CGPoint(x: 100, y: 430))
        #expect(above.y == tabletopFold.minY - layout.ringDiameter / 2)
    }

    @Test func ringsAwayFromTheFoldDoNotMove() {
        let layout = layout(bookFold)
        let point = CGPoint(x: 80, y: 400)
        #expect(layout.ringCentre(for: point) == point)
    }

    @Test func landscapeBookPosture() {
        // Rotated device: fold runs top to bottom in a landscape canvas.
        let layout = layout(CGRect(x: 425, y: 0, width: 40, height: 626), size: CGSize(width: 890, height: 626))
        #expect(layout.revealRect.width == 425)
    }
}
