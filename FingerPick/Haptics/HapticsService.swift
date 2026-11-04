import CoreHaptics
import FingerPickKit
import UIKit

/// The haptic vocabulary of a round.
@MainActor
protocol HapticsService: AnyObject {
    /// Light tap when a finger lands.
    func touchDown()
    /// Soft tick once a second during the countdown. `intensity` rises from about 0.4 to 1.
    func countdownTick(intensity: Float)
    /// Strong pattern on the reveal.
    func success()
    /// Soft tap when a round is cancelled (countdown cancelled, phone folded).
    func cancelled()
}

enum HapticsKind: Equatable {
    case off, coreHaptics, feedbackGenerators
}

enum Haptics {
    /// Settings key for the haptics toggle (default on).
    static let enabledKey = "hapticsEnabled"

    static func kind(enabled: Bool, supportsCoreHaptics: Bool) -> HapticsKind {
        guard enabled else { return .off }
        return supportsCoreHaptics ? .coreHaptics : .feedbackGenerators
    }

    @MainActor
    static func make(_ kind: HapticsKind) -> any HapticsService {
        switch kind {
        case .off: NoHaptics()
        case .coreHaptics: CoreHapticsService() ?? FeedbackGeneratorHaptics()
        case .feedbackGenerators: FeedbackGeneratorHaptics()
        }
    }

    @MainActor
    static func make(enabled: Bool) -> any HapticsService {
        make(kind(enabled: enabled, supportsCoreHaptics: CHHapticEngine.capabilitiesForHardware().supportsHaptics))
    }
}

/// Maps round events to haptics.
@MainActor
final class HapticsDirector {
    var service: any HapticsService

    init(service: any HapticsService) {
        self.service = service
    }

    func handle(_ events: [RoundEvent], countdownDuration: TimeInterval) {
        for event in events {
            switch event {
            case .playerJoined:
                service.touchDown()
            case let .countdownTick(remaining):
                let total = max(1, countdownDuration.rounded(.up))
                let progress = 1 - (Double(remaining) - 1) / total
                service.countdownTick(intensity: Float(0.4 + 0.6 * progress))
            case .selected:
                service.success()
            case .countdownCancelled, .interrupted:
                service.cancelled()
            case .playerLeft, .countdownStarted, .reset:
                break
            }
        }
    }
}

final class NoHaptics: HapticsService {
    func touchDown() {}
    func countdownTick(intensity: Float) {}
    func success() {}
    func cancelled() {}
}

/// Fallback where Core Haptics isn't supported.
final class FeedbackGeneratorHaptics: HapticsService {
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let notification = UINotificationFeedbackGenerator()

    func touchDown() { light.impactOccurred() }
    func countdownTick(intensity: Float) { soft.impactOccurred(intensity: CGFloat(intensity)) }
    func success() { notification.notificationOccurred(.success) }
    func cancelled() { soft.impactOccurred(intensity: 0.5) }
}

/// Core Haptics patterns. Restarts the engine after the system resets or stops it.
final class CoreHapticsService: HapticsService {
    private let engine: CHHapticEngine
    private var needsStart = true

    init?() {
        guard let engine = try? CHHapticEngine() else { return nil }
        self.engine = engine
        engine.playsHapticsOnly = true
        engine.isAutoShutdownEnabled = true
        engine.resetHandler = { [weak self] in
            Task { @MainActor in self?.needsStart = true }
        }
        engine.stoppedHandler = { [weak self] _ in
            Task { @MainActor in self?.needsStart = true }
        }
    }

    func touchDown() {
        play([transient(at: 0, intensity: 0.5, sharpness: 0.6)])
    }

    func countdownTick(intensity: Float) {
        play([transient(at: 0, intensity: intensity, sharpness: 0.3)])
    }

    func success() {
        play([
            transient(at: 0, intensity: 1, sharpness: 1),
            CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4),
                ],
                relativeTime: 0.05, duration: 0.25
            ),
            transient(at: 0.35, intensity: 0.8, sharpness: 0.8),
        ])
    }

    func cancelled() {
        play([transient(at: 0, intensity: 0.35, sharpness: 0.1)])
    }

    private func transient(at time: TimeInterval, intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: time
        )
    }

    private func play(_ events: [CHHapticEvent]) {
        do {
            if needsStart {
                try engine.start()
                needsStart = false
            }
            let player = try engine.makePlayer(with: CHHapticPattern(events: events, parameters: []))
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            needsStart = true
        }
    }
}
