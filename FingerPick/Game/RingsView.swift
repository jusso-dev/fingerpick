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
            Canvas { context, size in
                frame.draw(in: &context, size: size, diameter: max(88, diameter))
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
        /// Picked in the showing result.
        var isPicked = false
    }

    var rings: [Ring] = []
    var now: TimeInterval
    var countdownElapsed: TimeInterval?
    var countdownProgress: Double?
    var cancelAge: TimeInterval?
    /// Seconds since the result was revealed.
    var revealAge: TimeInterval?

    @MainActor
    init(model: GameModel, now: TimeInterval) {
        self.now = now
        let picked = Set(model.reveal?.result.pickedPlayers ?? [])
        // Rings that would sit on an active fold are drawn clear of it; the touch still counts.
        let place = { (point: CGPoint) in model.layout.ringCentre(for: point) }
        for (id, position) in model.touches.positions.mapValues(place) {
            guard let marker = model.reveal?.markers[id] ?? model.slots.marker(for: id) else { continue }
            rings.append(Ring(
                marker: marker, position: position, age: now - (model.landedAt[id] ?? now), isPicked: picked.contains(id)
            ))
        }
        if let reveal = model.reveal {
            revealAge = now - reveal.startedAt
            // Picked players stay drawn after they lift.
            for id in picked where model.touches.positions[id] == nil {
                guard let marker = reveal.markers[id], let position = reveal.positions[id] else { continue }
                rings.append(Ring(marker: marker, position: place(position), age: 1, isPicked: true))
            }
        } else {
            for lifted in model.liftedRings where now - lifted.liftedAt < LiftedRing.fadeDuration {
                rings.append(Ring(
                    marker: lifted.marker, position: place(lifted.position), age: 1, liftedAge: now - lifted.liftedAt
                ))
            }
        }
        rings.sort { $0.marker.slot < $1.marker.slot }
        countdownProgress = model.engine.countdownProgress(at: now)
        if case let .countdown(start) = model.engine.phase {
            countdownElapsed = now - start
        }
        cancelAge = model.countdownCancelledAt.map { now - $0 }
    }

    func draw(in context: inout GraphicsContext, size: CGSize, diameter: CGFloat) {
        guard let revealAge else {
            for ring in rings { draw(ring, in: &context, diameter: diameter) }
            return
        }
        // Losers fade out.
        var losers = context
        losers.opacity = max(0, 1 - revealAge / Reveal.fadeDuration)
        for ring in rings where !ring.isPicked {
            draw(ring, in: &losers, diameter: diameter)
        }
        let winners = rings.filter(\.isPicked)
        // A single winner's colour grows from their finger to fill the screen.
        if winners.count == 1, let winner = winners.first {
            let t = min(1, revealAge / Reveal.expandDuration)
            let eased = 1 - pow(1 - t, 3)
            let corners = [
                CGPoint.zero, CGPoint(x: size.width, y: 0), CGPoint(x: 0, y: size.height), CGPoint(x: size.width, y: size.height),
            ]
            let farthest = corners.map { hypot($0.x - winner.position.x, $0.y - winner.position.y) }.max() ?? 0
            let radius = diameter / 2 + (farthest - diameter / 2) * eased
            let rect = CGRect(x: winner.position.x - radius, y: winner.position.y - radius, width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: rect), with: .color(Palette.colour(winner.marker)))
            draw(winner, in: &context, diameter: diameter, inverted: true)
        } else {
            for ring in winners { draw(ring, in: &context, diameter: diameter) }
        }
    }

    /// Draws one ring. `inverted` draws it in the background colour, over the winner's colour fill.
    private func draw(_ ring: Ring, in context: inout GraphicsContext, diameter: CGFloat, inverted: Bool = false) {
        let playerColour = Palette.colour(ring.marker)
        let colour = inverted ? Color(.systemBackground) : playerColour
        var scale = scaleIn(age: ring.age) * (revealAge == nil ? pulse : 1)
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
        if revealAge == nil { layer.fill(circle, with: .color(colour.opacity(0.18))) }
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

        drawBadge(
            for: ring.marker, fill: colour, text: inverted ? playerColour : Color(.systemBackground),
            centre: centre, radius: radius, in: &layer
        )
    }

    /// Shape and number above the ring (below it near the top edge), clear of the fingertip.
    private func drawBadge(
        for marker: PlayerMarker, fill: Color, text: Color, centre: CGPoint, radius: CGFloat,
        in context: inout GraphicsContext
    ) {
        let label = context.resolve(
            Text("\(Image(systemName: Palette.symbol(marker))) \(marker.number)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(text)
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
        context.fill(Path(roundedRect: rect, cornerRadius: badgeSize.height / 2), with: .color(fill))
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
