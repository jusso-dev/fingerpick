import FingerPickKit
import SwiftUI

/// Draws a ring under every finger, at display refresh rate (up to 120 Hz on ProMotion).
struct RingsView: View {
    let model: GameModel
    /// Ring diameter in points. Never below 88 pt so it shows around a fingertip.
    var diameter: CGFloat = 100

    var body: some View {
        TimelineView(.animation) { _ in
            let frame = RingFrame(model: model, now: model.now())
            Canvas { context, _ in
                frame.draw(in: &context, diameter: max(88, diameter))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Everything needed to draw one frame, captured on the main actor.
struct RingFrame {
    struct Ring {
        let marker: PlayerMarker
        let position: CGPoint
        let age: TimeInterval
        /// Seconds since the finger lifted, if it has.
        var liftedAge: TimeInterval?
    }

    var rings: [Ring] = []
    var now: TimeInterval
    var countdownElapsed: TimeInterval?
    var countdownProgress: Double?
    var cancelAge: TimeInterval?

    @MainActor
    init(model: GameModel, now: TimeInterval) {
        self.now = now
        for (id, position) in model.touches.positions {
            guard let marker = model.slots.marker(for: id) else { continue }
            rings.append(Ring(marker: marker, position: position, age: now - (model.landedAt[id] ?? now)))
        }
        for lifted in model.liftedRings where now - lifted.liftedAt < LiftedRing.fadeDuration {
            rings.append(Ring(marker: lifted.marker, position: lifted.position, age: 1, liftedAge: now - lifted.liftedAt))
        }
        rings.sort { $0.marker.slot < $1.marker.slot }
        countdownProgress = model.engine.countdownProgress(at: now)
        if case let .countdown(start) = model.engine.phase {
            countdownElapsed = now - start
        }
        cancelAge = model.countdownCancelledAt.map { now - $0 }
    }

    func draw(in context: inout GraphicsContext, diameter: CGFloat) {
        for ring in rings {
            draw(ring, in: &context, diameter: diameter)
        }
    }

    private func draw(_ ring: Ring, in context: inout GraphicsContext, diameter: CGFloat) {
        let colour = Palette.colour(ring.marker)
        var scale = scaleIn(age: ring.age) * pulse
        var opacity = 1.0
        if let lifted = ring.liftedAge {
            let t = min(1, lifted / LiftedRing.fadeDuration)
            opacity = 1 - t
            scale *= 1 + 0.2 * t
        }
        let radius = diameter / 2 * scale
        let centre = CGPoint(x: ring.position.x + shake, y: ring.position.y)
        let circle = Path(ellipseIn: CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2))

        var layer = context
        layer.opacity = opacity
        layer.fill(circle, with: .color(colour.opacity(0.18)))
        layer.stroke(circle, with: .color(colour), lineWidth: 10)

        if let progress = countdownProgress, ring.liftedAge == nil {
            let sweepRadius = radius + 12
            var arc = Path()
            arc.addArc(
                center: centre, radius: sweepRadius,
                startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * progress), clockwise: false
            )
            layer.stroke(arc, with: .color(colour), style: StrokeStyle(lineWidth: 6, lineCap: .round))
        }

        drawBadge(for: ring.marker, colour: colour, centre: centre, radius: radius, in: &layer)
    }

    /// Shape and number above the ring (below it near the top edge), clear of the fingertip.
    private func drawBadge(
        for marker: PlayerMarker, colour: Color, centre: CGPoint, radius: CGFloat, in context: inout GraphicsContext
    ) {
        let label = context.resolve(
            Text("\(Image(systemName: Palette.symbol(marker))) \(marker.number)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(Color(.systemBackground))
        )
        let textSize = label.measure(in: CGSize(width: 200, height: 100))
        let badgeSize = CGSize(width: textSize.width + 16, height: textSize.height + 8)
        let gap: CGFloat = 20
        var y = centre.y - radius - gap - badgeSize.height / 2
        if y - badgeSize.height / 2 < 0 {
            y = centre.y + radius + gap + badgeSize.height / 2
        }
        let rect = CGRect(
            x: centre.x - badgeSize.width / 2, y: y - badgeSize.height / 2,
            width: badgeSize.width, height: badgeSize.height
        )
        context.fill(Path(roundedRect: rect, cornerRadius: badgeSize.height / 2), with: .color(colour))
        context.draw(label, at: CGPoint(x: rect.midX, y: rect.midY))
    }

    // MARK: Motion

    private func scaleIn(age: TimeInterval) -> CGFloat {
        let t = min(1, age / 0.15)
        return 0.6 + 0.4 * (1 - pow(1 - t, 3))
    }

    /// Subtle idle pulse; during the countdown every ring pulses together once a second.
    private var pulse: CGFloat {
        if let elapsed = countdownElapsed {
            let phase = elapsed - elapsed.rounded(.down)
            return 1 + 0.08 * pow(1 - phase, 2)
        }
        return 1 + 0.03 * sin(2 * .pi * now / 1.6)
    }

    /// Brief horizontal shake when the countdown is cancelled.
    private var shake: CGFloat {
        guard let age = cancelAge, age < 0.4 else { return 0 }
        return 8 * sin(age * 50) * (1 - age / 0.4)
    }
}
