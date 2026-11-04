import FingerPickKit
import SwiftUI

/// Draws a ring under every finger, at display refresh rate (up to 120 Hz on ProMotion).
struct RingsView: View {
    let model: GameModel
    /// Ring diameter in points. Never below 88 pt so it shows around a fingertip.
    var diameter: CGFloat = 100

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        TimelineView(.animation) { _ in
            let frame = RingFrame(
                model: model, now: model.now(), reduceMotion: reduceMotion, increasedContrast: contrast == .increased
            )
            Canvas { context, size in
                frame.draw(in: &context, size: size, diameter: max(88, diameter))
            }
        }
        // Badges sit around a fingertip, so they stop growing at the first accessibility size.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Everything needed to draw one frame, captured on the main actor.
struct RingFrame {
    /// A ring's part in the showing result.
    enum Outcome: Equatable {
        case none, winner, loser
        /// Zero-based team.
        case team(Int)
        /// One-based turn.
        case rank(Int)
    }

    struct Ring {
        let marker: PlayerMarker
        let position: CGPoint
        let age: TimeInterval
        /// Seconds since the finger lifted, if it has.
        var liftedAge: TimeInterval?
        var outcome: Outcome = .none
    }

    enum Style: Equatable {
        case plain
        /// Background colour, over the winner's colour fill.
        case inverted
        /// One of several winners: extra halo.
        case highlighted
        /// Team colour and team badge.
        case team(Int)
        /// Turn number badge.
        case rank(Int)
    }

    /// Delay between each rank appearing in an order reveal.
    static let rankInterval: TimeInterval = 0.35

    var rings: [Ring] = []
    var now: TimeInterval
    var countdownElapsed: TimeInterval?
    var countdownProgress: Double?
    var cancelAge: TimeInterval?
    /// Seconds since the result was revealed.
    var revealAge: TimeInterval?
    /// Reduce Motion: fades and colour changes instead of pulses, scaling and shakes.
    var reduceMotion = false
    /// Increase Contrast: thicker ring outlines.
    var increasedContrast = false

    @MainActor
    init(model: GameModel, now: TimeInterval, reduceMotion: Bool = false, increasedContrast: Bool = false) {
        self.now = now
        self.reduceMotion = reduceMotion
        self.increasedContrast = increasedContrast
        let result = model.reveal?.result
        // Rings that would sit on an active fold are drawn clear of it; the touch still counts.
        let place = { (point: CGPoint) in model.layout.ringCentre(for: point) }
        for (id, position) in model.touches.positions.mapValues(place) {
            guard let marker = model.reveal?.markers[id] ?? model.slots.marker(for: id) else { continue }
            rings.append(Ring(
                marker: marker, position: position, age: now - (model.landedAt[id] ?? now),
                outcome: result.map { Self.outcome(of: id, in: $0) } ?? .none
            ))
        }
        if let reveal = model.reveal {
            revealAge = now - reveal.startedAt
            // Everyone in the result stays drawn after they lift.
            for id in reveal.result.pickedPlayers where model.touches.positions[id] == nil {
                guard let marker = reveal.markers[id], let position = reveal.positions[id] else { continue }
                rings.append(Ring(
                    marker: marker, position: place(position), age: 1, outcome: Self.outcome(of: id, in: reveal.result)
                ))
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

    static func outcome(of id: PlayerID, in result: RoundResult) -> Outcome {
        switch result {
        case let .winners(ids): ids.contains(id) ? .winner : .loser
        case .teams: result.team(of: id).map(Outcome.team) ?? .loser
        case .order: result.rank(of: id).map(Outcome.rank) ?? .loser
        }
    }

    // MARK: Drawing

    func draw(in context: inout GraphicsContext, size: CGSize, diameter: CGFloat) {
        guard let revealAge else {
            for ring in rings { draw(ring, in: &context, diameter: diameter) }
            return
        }
        let fade = min(1, revealAge / Reveal.fadeDuration)
        var losers = context
        losers.opacity = 1 - fade
        for ring in rings where ring.outcome == .loser || ring.outcome == .none {
            draw(ring, in: &losers, diameter: diameter)
        }
        let winners = rings.filter { $0.outcome == .winner }
        if winners.count == 1, let winner = winners.first {
            drawFill(for: winner, in: &context, size: size, diameter: diameter, age: revealAge)
            draw(winner, in: &context, diameter: diameter, style: .inverted)
        } else {
            for ring in winners { draw(ring, in: &context, diameter: diameter, style: .highlighted) }
        }
        for ring in rings {
            switch ring.outcome {
            case let .team(team):
                // Cross-fade from the player's colour to the team's.
                var own = context
                own.opacity = 1 - fade
                draw(ring, in: &own, diameter: diameter)
                var teamLayer = context
                teamLayer.opacity = fade
                draw(ring, in: &teamLayer, diameter: diameter, style: .team(team))
            case let .rank(rank):
                // Ranks appear one by one, first place first.
                let shown = revealAge >= Double(rank - 1) * Self.rankInterval
                var layer = context
                layer.opacity = shown ? 1 : 0.3
                draw(ring, in: &layer, diameter: diameter, style: shown ? .rank(rank) : .plain)
            case .none, .winner, .loser:
                break
            }
        }
    }

    /// A single winner's colour grows from their finger to fill the screen.
    private func drawFill(
        for winner: Ring, in context: inout GraphicsContext, size: CGSize, diameter: CGFloat, age: TimeInterval
    ) {
        let t = min(1, age / Reveal.expandDuration)
        let eased = 1 - pow(1 - t, 3)
        let corners = [
            CGPoint.zero, CGPoint(x: size.width, y: 0), CGPoint(x: 0, y: size.height), CGPoint(x: size.width, y: size.height),
        ]
        let farthest = corners.map { hypot($0.x - winner.position.x, $0.y - winner.position.y) }.max() ?? 0
        let radius = diameter / 2 + (farthest - diameter / 2) * eased
        let rect = CGRect(x: winner.position.x - radius, y: winner.position.y - radius, width: radius * 2, height: radius * 2)
        if reduceMotion {
            // Cross-fade the whole screen to the winner's colour instead of growing a circle.
            var layer = context
            layer.opacity = t
            layer.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Palette.colour(winner.marker)))
            return
        }
        context.fill(Path(ellipseIn: rect), with: .color(Palette.colour(winner.marker)))
    }

    private func draw(_ ring: Ring, in context: inout GraphicsContext, diameter: CGFloat, style: Style = .plain) {
        let marker = if case let .team(team) = style { PlayerMarker(slot: team) } else { ring.marker }
        let playerColour = Palette.colour(marker)
        let colour = style == .inverted ? Color(.systemBackground) : playerColour
        var scale = scaleIn(age: ring.age) * (revealAge == nil ? pulse : 1)
        var opacity = reduceMotion ? min(1, ring.age / 0.15) * cancelFlash : 1
        if let lifted = ring.liftedAge {
            let t = min(1, lifted / LiftedRing.fadeDuration)
            opacity = 1 - t
            if !reduceMotion { scale *= 1 + 0.2 * t }
        }
        if case let .rank(rank) = style, let revealAge, !reduceMotion {
            // Small pop as each rank appears.
            scale *= 1 + 0.15 * max(0, 1 - (revealAge - Double(rank - 1) * Self.rankInterval) / 0.2)
        }
        let radius = diameter / 2 * scale
        let centre = CGPoint(x: ring.position.x + shake, y: ring.position.y)

        var layer = context
        layer.opacity = opacity
        let circle = Path(ellipseIn: square(centre, radius))
        if style != .inverted { layer.fill(circle, with: .color(colour.opacity(0.18))) }
        layer.stroke(circle, with: .color(colour), lineWidth: increasedContrast ? 14 : 10)
        if style == .highlighted {
            layer.stroke(Path(ellipseIn: square(centre, radius + 14)), with: .color(colour), lineWidth: 4)
        }

        if let progress = countdownProgress, ring.liftedAge == nil {
            var arc = Path()
            arc.addArc(
                center: centre, radius: radius + 12,
                startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * progress), clockwise: false
            )
            layer.stroke(arc, with: .color(colour), style: StrokeStyle(lineWidth: 6, lineCap: .round))
        }

        let symbol = Image(systemName: Palette.symbol(marker))
        let text: Text = switch style {
        case let .team(team): Text("\(symbol) Team \(team + 1)")
        case let .rank(rank): Text("\(symbol) #\(rank)").font(.title2.bold().monospacedDigit())
        default: Text("\(symbol) \(marker.number)")
        }
        let textColour = style == .inverted ? playerColour : Color(.systemBackground)
        drawBadge(text.foregroundStyle(textColour), fill: colour, centre: centre, radius: radius, in: &layer)
    }

    private func square(_ centre: CGPoint, _ radius: CGFloat) -> CGRect {
        CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2)
    }

    /// Badge above the ring (below it near the top edge), clear of the fingertip.
    private func drawBadge(_ text: Text, fill: Color, centre: CGPoint, radius: CGFloat, in context: inout GraphicsContext) {
        let label = context.resolve(text.font(.headline.monospacedDigit()))
        let textSize = label.measure(in: CGSize(width: 240, height: 100))
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
        let badge = Path(roundedRect: rect, cornerRadius: badgeSize.height / 2)
        context.fill(badge, with: .color(fill))
        if increasedContrast {
            context.stroke(badge, with: .color(.primary), lineWidth: 2)
        }
        context.draw(label, at: CGPoint(x: rect.midX, y: rect.midY))
    }

    // MARK: Motion

    private func scaleIn(age: TimeInterval) -> CGFloat {
        guard !reduceMotion else { return 1 }
        let t = min(1, age / 0.15)
        return 0.6 + 0.4 * (1 - pow(1 - t, 3))
    }

    /// Subtle idle pulse; during the countdown every ring pulses together once a second.
    private var pulse: CGFloat {
        guard !reduceMotion else { return 1 }
        if let elapsed = countdownElapsed {
            let phase = elapsed - elapsed.rounded(.down)
            return 1 + 0.08 * pow(1 - phase, 2)
        }
        return 1 + 0.03 * sin(2 * .pi * now / 1.6)
    }

    /// Brief horizontal shake when the countdown is cancelled.
    private var shake: CGFloat {
        guard !reduceMotion, let age = cancelAge, age < 0.4 else { return 0 }
        return 8 * sin(age * 50) * (1 - age / 0.4)
    }

    /// Reduce Motion alternative to the shake: rings dim briefly when the countdown is cancelled.
    private var cancelFlash: Double {
        guard let age = cancelAge, age < 0.4 else { return 1 }
        return 0.4 + 0.6 * age / 0.4
    }
}
