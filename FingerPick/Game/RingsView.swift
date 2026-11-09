import FingerPickKit
import SwiftUI

/// Draws a ring under every finger, at display refresh rate (up to 120 Hz on ProMotion). Redrawing
/// pauses when nothing is on screen, so the waiting screen costs no battery.
struct RingsView: View {
    let model: GameModel
    /// Ring diameter in points. Never below 88 pt so it shows around a fingertip.
    var diameter: CGFloat = 100

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: model.isStill)) { _ in
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

    /// The last result, fading out after the reset.
    struct Exit {
        let rings: [Ring]
        let fillsScreen: Bool
        /// How far the winner's colour had grown when the result ended.
        let fillAge: TimeInterval
        let alpha: Double

        init?(ended: EndedReveal, now: TimeInterval, place: (CGPoint) -> CGPoint) {
            guard now - ended.endedAt < EndedReveal.fadeDuration else { return nil }
            let old = ended.reveal
            rings = old.result.pickedPlayers.compactMap { id in
                guard let marker = old.markers[id], let position = old.positions[id] else { return nil }
                return Ring(marker: marker, position: place(position), age: 1, outcome: RingFrame.outcome(of: id, in: old.result))
            }
            fillsScreen = old.fillsScreen
            fillAge = ended.endedAt - old.startedAt
            alpha = 1 - (now - ended.endedAt) / EndedReveal.fadeDuration
        }
    }

    /// Delay between each rank appearing in an order reveal.
    static let rankInterval: TimeInterval = 0.35
    /// Delay between each of several winners popping.
    static let winnerInterval: TimeInterval = 0.08

    var rings: [Ring] = []
    var now: TimeInterval
    var countdownElapsed: TimeInterval?
    var countdownProgress: Double?
    var cancelAge: TimeInterval?
    /// Seconds since the result was revealed.
    var revealAge: TimeInterval?
    var exit: Exit?
    /// Reduce Motion: fades and colour changes instead of pulses, scaling, ripples and shakes.
    var reduceMotion = false
    /// Increase Contrast: thicker ring outlines.
    var increasedContrast = false

    @MainActor
    init(model: GameModel, now: TimeInterval, reduceMotion: Bool = false, increasedContrast: Bool = false) {
        self.now = now
        self.reduceMotion = reduceMotion
        self.increasedContrast = increasedContrast
        let reveal = model.reveal
        // Rings that would sit on an active fold are drawn clear of it; the touch still counts.
        let place = { (point: CGPoint) in model.layout.ringCentre(for: point) }
        for (id, position) in model.touches.positions.mapValues(place) {
            guard let marker = reveal?.markers[id] ?? model.slots.marker(for: id) else { continue }
            // A finger that landed after the pick isn't part of the result.
            let outcome = reveal.flatMap { $0.markers[id] == nil ? nil : Self.outcome(of: id, in: $0.result) } ?? .none
            rings.append(Ring(marker: marker, position: position, age: now - (model.landedAt[id] ?? now), outcome: outcome))
        }
        if let reveal {
            revealAge = now - reveal.startedAt
            // Everyone in the result stays drawn after they lift.
            let picked = reveal.result.pickedPlayers
            for id in picked where model.touches.positions[id] == nil {
                guard let marker = reveal.markers[id], let position = reveal.positions[id] else { continue }
                rings.append(Ring(
                    marker: marker, position: place(position), age: 1, outcome: Self.outcome(of: id, in: reveal.result)
                ))
            }
            // Losers who lift during the reveal fade out with the others rather than vanish.
            let pickedSlots = Set(picked.compactMap { reveal.markers[$0]?.slot })
            for lifted in model.liftedRings
            where now - lifted.liftedAt < LiftedRing.fadeDuration && !pickedSlots.contains(lifted.marker.slot) {
                rings.append(Ring(
                    marker: lifted.marker, position: place(lifted.position), age: 1,
                    liftedAge: now - lifted.liftedAt, outcome: .loser
                ))
            }
        } else {
            for lifted in model.liftedRings where now - lifted.liftedAt < LiftedRing.fadeDuration {
                rings.append(Ring(
                    marker: lifted.marker, position: place(lifted.position), age: 1, liftedAge: now - lifted.liftedAt
                ))
            }
            exit = model.endedReveal.flatMap { Exit(ended: $0, now: now, place: place) }
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
        if let exit { drawExit(exit, in: &context, size: size, diameter: diameter) }
        guard let revealAge else {
            for ring in rings { draw(ring, in: &context, diameter: diameter) }
            return
        }
        // Losers shrink a little as they fade, so the winners stand out.
        let fade = min(1, revealAge / Reveal.fadeDuration)
        for ring in rings where ring.outcome == .loser {
            draw(ring, in: &context, diameter: diameter, alpha: 1 - fade, scale: reduceMotion ? 1 : 1 - 0.15 * fade)
        }
        let winners = rings.filter { $0.outcome == .winner }
        if winners.count == 1, let winner = winners.first {
            drawFill(for: winner, in: &context, size: size, diameter: diameter, age: revealAge)
            draw(winner, in: &context, diameter: diameter, style: .inverted, popAge: revealAge)
        } else {
            for (index, ring) in winners.enumerated() {
                let age = revealAge - Double(index) * Self.winnerInterval
                draw(ring, in: &context, diameter: diameter, style: .highlighted, popAge: age)
            }
        }
        drawTeamsAndRanks(in: &context, diameter: diameter, revealAge: revealAge, fade: fade)
        // Fingers that landed after the pick, on top.
        for ring in rings where ring.outcome == .none {
            draw(ring, in: &context, diameter: diameter)
        }
    }

    private func drawTeamsAndRanks(in context: inout GraphicsContext, diameter: CGFloat, revealAge: TimeInterval, fade: Double) {
        for ring in rings {
            switch ring.outcome {
            case let .team(team):
                // Cross-fade from the player's colour to the team's.
                draw(ring, in: &context, diameter: diameter, alpha: 1 - fade)
                draw(ring, in: &context, diameter: diameter, style: .team(team), alpha: fade)
            case let .rank(rank):
                // Ranks appear one by one, first place first.
                let age = revealAge - Double(rank - 1) * Self.rankInterval
                let shown = age >= 0
                draw(ring, in: &context, diameter: diameter, style: shown ? .rank(rank) : .plain, alpha: shown ? 1 : 0.3, popAge: age)
            case .none, .winner, .loser:
                break
            }
        }
    }

    /// The last result fades out instead of vanishing in one frame.
    private func drawExit(_ exit: Exit, in context: inout GraphicsContext, size: CGSize, diameter: CGFloat) {
        let winners = exit.rings.filter { $0.outcome == .winner }
        if exit.fillsScreen, let winner = winners.first {
            drawFill(for: winner, in: &context, size: size, diameter: diameter, age: exit.fillAge, alpha: exit.alpha)
        }
        for ring in exit.rings {
            let style: Style = switch ring.outcome {
            case .winner: exit.fillsScreen ? .inverted : .highlighted
            case let .team(team): .team(team)
            case let .rank(rank): .rank(rank)
            case .none, .loser: .plain
            }
            draw(ring, in: &context, diameter: diameter, style: style, alpha: exit.alpha)
        }
    }

    /// A single winner's colour grows from their finger to fill the screen.
    private func drawFill(
        for winner: Ring, in context: inout GraphicsContext, size: CGSize, diameter: CGFloat, age: TimeInterval,
        alpha: Double = 1
    ) {
        let t = min(1, age / Reveal.expandDuration)
        let eased = 1 - pow(1 - t, 3)
        let corners = [
            CGPoint.zero, CGPoint(x: size.width, y: 0), CGPoint(x: 0, y: size.height), CGPoint(x: size.width, y: size.height),
        ]
        let farthest = corners.map { hypot($0.x - winner.position.x, $0.y - winner.position.y) }.max() ?? 0
        let radius = diameter / 2 + (farthest - diameter / 2) * eased
        let rect = CGRect(x: winner.position.x - radius, y: winner.position.y - radius, width: radius * 2, height: radius * 2)
        var layer = context
        let colour = Palette.colour(winner.marker)
        if reduceMotion {
            // Cross-fade the whole screen to the winner's colour instead of growing a circle.
            layer.opacity = t * alpha
            layer.fill(Path(CGRect(origin: .zero, size: size)), with: .color(colour))
            return
        }
        layer.opacity = alpha
        layer.fill(Path(ellipseIn: rect), with: .color(colour))
    }

    /// - Parameters:
    ///   - alpha: Opacity of the whole ring, for fades.
    ///   - scale: Extra scale, for losers shrinking.
    ///   - popAge: Seconds since this ring was picked, for the pop and ripple.
    private func draw(
        _ ring: Ring, in context: inout GraphicsContext, diameter: CGFloat, style: Style = .plain,
        alpha: Double = 1, scale extraScale: CGFloat = 1, popAge: TimeInterval? = nil
    ) {
        guard alpha > 0 else { return }
        let marker = if case let .team(team) = style { PlayerMarker(slot: team) } else { ring.marker }
        let playerColour = Palette.colour(marker)
        let colour = style == .inverted ? Color(.systemBackground) : playerColour
        var scale = scaleIn(age: ring.age) * (revealAge == nil ? pulse : 1) * extraScale
        var opacity = reduceMotion ? min(1, ring.age / 0.15) * cancelFlash : 1
        if let lifted = ring.liftedAge {
            let t = min(1, lifted / LiftedRing.fadeDuration)
            opacity = 1 - t
            if !reduceMotion { scale *= 1 + 0.2 * t }
        }
        if let popAge, !reduceMotion {
            scale *= 1 + 0.15 * Self.bump(popAge, duration: 0.3)
        }
        let radius = diameter / 2 * scale
        let centre = CGPoint(x: ring.position.x + shake, y: ring.position.y)

        drawRipples(for: ring, centre: centre, radius: radius, popAge: popAge, colour: colour, in: context)
        var layer = context
        layer.opacity = opacity * alpha
        let circle = Path(ellipseIn: square(centre, radius))
        if style != .inverted { layer.fill(circle, with: .color(colour.opacity(0.18))) }
        layer.stroke(circle, with: .color(colour), lineWidth: increasedContrast ? 14 : 10)
        if style == .highlighted {
            layer.stroke(Path(ellipseIn: square(centre, radius + 14)), with: .color(colour), lineWidth: 4)
        }

        if let progress = countdownProgress, ring.liftedAge == nil {
            drawCountdown(progress: progress, centre: centre, radius: radius + 12, colour: colour, in: &layer)
        }

        let text = Self.badgeText(marker, style: style)
        // Inverted badges are the background colour over the winner's fill, so the text uses the
        // label colour; elsewhere black or white, whichever reads better on the player colour.
        let textColour = style == .inverted ? Color(.label) : Palette.text(on: colour, in: context.environment)
        drawBadge(text.foregroundStyle(textColour), fill: colour, centre: centre, radius: radius, in: &layer)
    }

    private static func badgeText(_ marker: PlayerMarker, style: Style) -> Text {
        let symbol = Image(systemName: Palette.symbol(marker))
        return switch style {
        case let .team(team): Text("\(symbol) Team \(team + 1)")
        case let .rank(rank): Text("\(symbol) #\(rank)").font(.title2.bold().monospacedDigit())
        default: Text("\(symbol) \(marker.number)")
        }
    }

    /// A ripple as the finger lands, and a bigger one when the ring is picked.
    private func drawRipples(
        for ring: Ring, centre: CGPoint, radius: CGFloat, popAge: TimeInterval?, colour: Color, in context: GraphicsContext
    ) {
        guard !reduceMotion, ring.liftedAge == nil else { return }
        if revealAge == nil, ring.age < 0.5 {
            drawRipple(centre: centre, radius: radius, progress: ring.age / 0.5, reach: 0.7, colour: colour, in: context)
        }
        if let popAge, popAge >= 0, popAge < 0.7 {
            drawRipple(centre: centre, radius: radius, progress: popAge / 0.7, reach: 1.4, colour: colour, in: context)
        }
    }

    private func drawRipple(
        centre: CGPoint, radius: CGFloat, progress: Double, reach: CGFloat, colour: Color, in context: GraphicsContext
    ) {
        let eased = 1 - pow(1 - progress, 2)
        var ripple = context
        ripple.opacity = 0.6 * (1 - progress)
        ripple.stroke(Path(ellipseIn: square(centre, radius * (1 + reach * eased))), with: .color(colour), lineWidth: 3)
    }

}

extension RingFrame {
    /// Faint full track, the arc filling it, and a glow that builds as the pick gets closer.
    private func drawCountdown(progress: Double, centre: CGPoint, radius: CGFloat, colour: Color, in context: inout GraphicsContext) {
        context.stroke(Path(ellipseIn: square(centre, radius)), with: .color(colour.opacity(0.2)), lineWidth: 7)
        var arc = Path()
        arc.addArc(
            center: centre, radius: radius,
            startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * progress), clockwise: false
        )
        if !reduceMotion {
            context.stroke(
                arc, with: .color(colour.opacity(0.3 * progress)),
                style: StrokeStyle(lineWidth: 7 + 12 * progress, lineCap: .round)
            )
        }
        context.stroke(arc, with: .color(colour), style: StrokeStyle(lineWidth: 7, lineCap: .round))
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
}
