import FingerPickKit
import Testing
@testable import FingerPick

@MainActor
final class SpyHaptics: HapticsService {
    var calls: [String] = []
    var intensities: [Float] = []
    func touchDown() { calls.append("touch") }
    func countdownTick(intensity: Float) { calls.append("tick"); intensities.append(intensity) }
    func success() { calls.append("success") }
    func cancelled() { calls.append("cancelled") }
}

@MainActor
struct HapticsTests {
    @Test func toggleOffSilencesEverything() {
        #expect(Haptics.kind(enabled: false, supportsCoreHaptics: true) == .off)
        #expect(Haptics.kind(enabled: false, supportsCoreHaptics: false) == .off)
        #expect(Haptics.make(.off) is NoHaptics)
    }

    @Test func choosesCoreHapticsWhenSupported() {
        #expect(Haptics.kind(enabled: true, supportsCoreHaptics: true) == .coreHaptics)
        #expect(Haptics.kind(enabled: true, supportsCoreHaptics: false) == .feedbackGenerators)
        #expect(Haptics.make(.feedbackGenerators) is FeedbackGeneratorHaptics)
    }

    @Test func coreHapticsServiceDoesNotCrashWithoutHardware() {
        // On the simulator the engine may not exist; the factory must still return a service.
        let service = Haptics.make(.coreHaptics)
        service.touchDown()
        service.success()
    }

    @Test func eventsMapToPatterns() {
        let spy = SpyHaptics()
        let director = HapticsDirector(service: spy)
        director.handle([
            .playerJoined(PlayerID(0)), .countdownStarted,
            .countdownTick(secondsRemaining: 3), .countdownTick(secondsRemaining: 2), .countdownTick(secondsRemaining: 1),
            .selected(.winners([PlayerID(0)])), .countdownCancelled, .interrupted, .reset,
        ], countdownDuration: 3)
        #expect(spy.calls == ["touch", "tick", "tick", "tick", "success", "cancelled", "cancelled"])
        #expect(spy.intensities == spy.intensities.sorted())
        #expect(spy.intensities.last == 1)
    }
}
