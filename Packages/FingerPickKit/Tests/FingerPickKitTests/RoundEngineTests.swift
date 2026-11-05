import Foundation
import Testing
@testable import FingerPickKit

/// Always picks the lowest player ID, so tests can predict the winner.
struct LowestPicker: Picker {
    mutating func pick(from players: [PlayerID], mode: PickMode) -> RoundResult {
        .winners([players.min()!])
    }
}

private let p0 = PlayerID(0), p1 = PlayerID(1), p2 = PlayerID(2)

/// Default timings: settle 1 s, countdown 3 s, reset 0.5 s.
private func makeEngine(_ configuration: RoundConfiguration = RoundConfiguration()) -> RoundEngine {
    RoundEngine(configuration: configuration, picker: LowestPicker())
}

/// Runs the engine with two fingers down at t = 0 through to a result at t = 4.
private func engineWithResult() -> RoundEngine {
    var engine = makeEngine()
    _ = engine.fingerDown(p0, at: 0)
    _ = engine.fingerDown(p1, at: 0)
    _ = engine.tick(at: 1)
    _ = engine.tick(at: 4)
    return engine
}

struct RoundEngineTests {
    @Test func startsWaiting() {
        let engine = makeEngine()
        #expect(engine.phase == .waiting)
        #expect(engine.nextDeadline(after: 0) == nil)
    }

    @Test func oneFingerKeepsWaiting() {
        var engine = makeEngine()
        #expect(engine.fingerDown(p0, at: 0) == [.playerJoined(p0)])
        #expect(engine.phase == .waiting)
        #expect(engine.tick(at: 100).isEmpty)
        #expect(engine.result == nil)
    }

    @Test func minimumFingersStartStabilising() {
        var engine = makeEngine()
        _ = engine.fingerDown(p0, at: 0)
        _ = engine.fingerDown(p1, at: 0.2)
        #expect(engine.phase == .stabilising(since: 0.2))
        #expect(engine.nextDeadline(after: 0.2) == 1.2)
    }

    @Test func settledFingersStartCountdownWithFirstTick() {
        var engine = makeEngine()
        _ = engine.fingerDown(p0, at: 0)
        _ = engine.fingerDown(p1, at: 0)
        #expect(engine.tick(at: 0.5).isEmpty)
        #expect(engine.tick(at: 1) == [.countdownStarted, .countdownTick(secondsRemaining: 3)])
        #expect(engine.phase == .countdown(startedAt: 1))
    }

    @Test func countdownTicksOncePerSecond() {
        var engine = makeEngine()
        _ = engine.fingerDown(p0, at: 0)
        _ = engine.fingerDown(p1, at: 0)
        _ = engine.tick(at: 1)
        #expect(engine.nextDeadline(after: 1) == 2)
        #expect(engine.tick(at: 1.5).isEmpty)
        #expect(engine.tick(at: 2) == [.countdownTick(secondsRemaining: 2)])
        #expect(engine.nextDeadline(after: 2) == 3)
        #expect(engine.tick(at: 3) == [.countdownTick(secondsRemaining: 1)])
        #expect(engine.nextDeadline(after: 3) == 4)
        #expect(engine.countdownProgress(at: 2.5) == 0.5)
    }

    @Test func countdownEndsWithSelection() {
        var engine = makeEngine()
        _ = engine.fingerDown(p1, at: 0)
        _ = engine.fingerDown(p0, at: 0)
        _ = engine.tick(at: 1)
        #expect(engine.tick(at: 4) == [.selected(.winners([p0]))])
        #expect(engine.result == .winners([p0]))
        #expect(engine.countdownProgress(at: 4) == nil)
    }

    @Test func lateTickStillSelectsOnce() {
        var engine = makeEngine()
        _ = engine.fingerDown(p0, at: 0)
        _ = engine.fingerDown(p1, at: 0)
        // A single late tick passes straight through stabilising and countdown.
        #expect(engine.tick(at: 10) == [.countdownStarted, .selected(.winners([p0]))])
        #expect(engine.tick(at: 11).isEmpty)
    }

    @Test(arguments: [true, false])
    func changingFingersDuringCountdownCancels(adding: Bool) {
        var engine = makeEngine()
        _ = engine.fingerDown(p0, at: 0)
        _ = engine.fingerDown(p1, at: 0)
        _ = engine.fingerDown(p2, at: 0)
        _ = engine.tick(at: 1)
        let events = adding ? engine.fingerDown(PlayerID(9), at: 2) : engine.fingerUp(p2, at: 2)
        #expect(events.last == .countdownCancelled)
        #expect(engine.phase == .stabilising(since: 2))
        // The countdown restarts only after a fresh settle period.
        #expect(engine.tick(at: 2.9).isEmpty)
        #expect(engine.tick(at: 3).first == .countdownStarted)
    }

    @Test func droppingBelowMinimumDuringCountdownReturnsToWaiting() {
        var engine = makeEngine()
        _ = engine.fingerDown(p0, at: 0)
        _ = engine.fingerDown(p1, at: 0)
        _ = engine.tick(at: 1)
        #expect(engine.fingerUp(p1, at: 2) == [.playerLeft(p1), .countdownCancelled])
        #expect(engine.phase == .waiting)
        #expect(engine.tick(at: 50).isEmpty)
    }

    @Test func changeWhileStabilisingRestartsTimer() {
        var engine = makeEngine()
        _ = engine.fingerDown(p0, at: 0)
        _ = engine.fingerDown(p1, at: 0)
        _ = engine.fingerDown(p2, at: 0.8)
        #expect(engine.tick(at: 1).isEmpty)
        #expect(engine.tick(at: 1.8).first == .countdownStarted)
    }

    @Test func neverSelectsWithFewerThanMinimum() {
        var engine = makeEngine(RoundConfiguration(minimumPlayers: 4))
        for id in 0..<3 { _ = engine.fingerDown(PlayerID(id), at: 0) }
        #expect(engine.tick(at: 100).isEmpty)
        #expect(engine.result == nil)
        _ = engine.fingerDown(PlayerID(3), at: 100)
        _ = engine.tick(at: 101)
        #expect(engine.tick(at: 104).last == .selected(.winners([p0])))
    }

    @Test func resultPersistsWhileFingersRemain() {
        var engine = engineWithResult()
        #expect(engine.fingerUp(p0, at: 5) == [.playerLeft(p0)])
        #expect(engine.result != nil)
        #expect(engine.tick(at: 60).isEmpty)
        #expect(engine.result != nil)
    }

    @Test func resetsHalfASecondAfterAllFingersLift() {
        var engine = engineWithResult()
        _ = engine.fingerUp(p0, at: 5)
        _ = engine.fingerUp(p1, at: 6)
        #expect(engine.nextDeadline(after: 6) == 6.5)
        #expect(engine.tick(at: 6.4).isEmpty)
        #expect(engine.tick(at: 6.5) == [.reset])
        #expect(engine.phase == .waiting)
    }

    @Test func fingerAddedDuringResultDoesNotRestart() {
        var engine = engineWithResult()
        #expect(engine.fingerDown(p2, at: 5) == [.playerJoined(p2)])
        _ = engine.fingerUp(p0, at: 5)
        _ = engine.fingerUp(p1, at: 5)
        // p2 is still down, so no reset is scheduled.
        #expect(engine.resetDeadline == nil)
        #expect(engine.tick(at: 30).isEmpty)
        _ = engine.fingerUp(p2, at: 31)
        #expect(engine.tick(at: 31.5) == [.reset])
    }

    @Test func fingerDuringResetPauseStartsNextRound() {
        var engine = engineWithResult()
        _ = engine.fingerUp(p0, at: 5)
        _ = engine.fingerUp(p1, at: 5)
        let events = engine.fingerDown(p2, at: 5.2)
        #expect(events == [.reset, .playerJoined(p2)])
        #expect(engine.phase == .waiting)
        #expect(engine.players == [p2])
    }

    @Test func tapDismissesResultOnlyWhenNoFingersDown() {
        var engine = engineWithResult()
        #expect(engine.dismissResult(at: 5).isEmpty)
        _ = engine.cancelAllFingers(at: 5)
        #expect(engine.dismissResult(at: 5.1) == [.reset])
        #expect(engine.dismissResult(at: 5.2).isEmpty)
    }

    @Test func tenRoundsInARowLeaveNoStaleState() {
        var engine = makeEngine()
        var now: TimeInterval = 0
        for round in 0..<10 {
            let ids = (0..<(2 + round)).map { PlayerID(round * 100 + $0) }
            for id in ids { _ = engine.fingerDown(id, at: now) }
            _ = engine.tick(at: now + 1)
            #expect(engine.tick(at: now + 4).last == .selected(.winners([ids[0]])))
            for id in ids { _ = engine.fingerUp(id, at: now + 5) }
            #expect(engine.tick(at: now + 5.5) == [.reset])
            #expect(engine.players.isEmpty)
            now += 10
        }
    }

    @Test func systemCancelClearsCountdown() {
        var engine = makeEngine()
        _ = engine.fingerDown(p0, at: 0)
        _ = engine.fingerDown(p1, at: 0)
        _ = engine.tick(at: 1)
        #expect(engine.cancelAllFingers(at: 2) == [.playerLeft(p0), .playerLeft(p1), .countdownCancelled])
        #expect(engine.phase == .waiting)
        #expect(engine.players.isEmpty)
        #expect(engine.cancelAllFingers(at: 2).isEmpty)
    }

    @Test func configurationChangesApply() {
        var engine = makeEngine()
        _ = engine.fingerDown(p0, at: 0)
        _ = engine.fingerDown(p1, at: 0)
        _ = engine.updateConfiguration(RoundConfiguration(minimumPlayers: 3), at: 0.5)
        #expect(engine.phase == .waiting)
        _ = engine.updateConfiguration(RoundConfiguration(minimumPlayers: 2, countdownDuration: 5), at: 0.6)
        #expect(engine.phase == .stabilising(since: 0.6))
        _ = engine.tick(at: 1.6)
        _ = engine.tick(at: 6.5)
        #expect(engine.result == nil)
        #expect(engine.tick(at: 6.6).isEmpty == false)
        #expect(engine.result != nil)
    }

    @Test func configurationClampsValues() {
        var configuration = RoundConfiguration(minimumPlayers: 0, countdownDuration: 9)
        #expect(configuration.minimumPlayers == 2)
        #expect(configuration.countdownDuration == 5)
        configuration.countdownDuration = 0.1
        configuration.minimumPlayers = 1
        #expect(configuration.countdownDuration == 1)
        #expect(configuration.minimumPlayers == 2)
    }

    @Test(arguments: [1.0, 2.0, 3.0, 4.0, 5.0])
    func countdownMatchesConfiguredDuration(duration: Double) {
        var engine = makeEngine(RoundConfiguration(countdownDuration: duration))
        _ = engine.fingerDown(p0, at: 0)
        _ = engine.fingerDown(p1, at: 0)
        _ = engine.tick(at: 1)
        #expect(engine.tick(at: 1 + duration - 0.001).contains { if case .selected = $0 { true } else { false } } == false)
        #expect(engine.tick(at: 1 + duration).last == .selected(.winners([p0])))
    }

}

/// Fold, unfold or display move during a round (#35).
struct RoundEngineEnvironmentTests {

    @Test func environmentChangeMidCountdownNeverPicks() {
        var engine = makeEngine()
        _ = engine.fingerDown(p0, at: 0)
        _ = engine.fingerDown(p1, at: 0)
        _ = engine.tick(at: 1)
        #expect(engine.environmentChanged(at: 2) == [.interrupted])
        #expect(engine.phase == .waiting)
        #expect(engine.players.isEmpty)
        #expect(engine.tick(at: 100).isEmpty)
        #expect(engine.result == nil)
    }

    @Test func environmentChangeAfterSystemCancelStillInterrupts() {
        // UIKit may cancel the touches before the size change arrives.
        var engine = makeEngine()
        _ = engine.fingerDown(p0, at: 0)
        _ = engine.fingerDown(p1, at: 0)
        _ = engine.tick(at: 1)
        _ = engine.cancelAllFingers(at: 2)
        #expect(engine.environmentChanged(at: 2.3) == [.interrupted])
        #expect(engine.environmentChanged(at: 2.4).isEmpty)
    }

    @Test func environmentChangeWhileIdleDoesNothing() {
        var engine = makeEngine()
        #expect(engine.environmentChanged(at: 0).isEmpty)
        _ = engine.fingerDown(p0, at: 1)
        _ = engine.cancelAllFingers(at: 1)
        #expect(engine.environmentChanged(at: 5).isEmpty)
    }

    @Test func resultSurvivesEnvironmentChange() {
        var engine = engineWithResult()
        _ = engine.cancelAllFingers(at: 5)
        #expect(engine.environmentChanged(at: 5.1).isEmpty)
        #expect(engine.isResultPinned)
        #expect(engine.nextDeadline(after: 5.1) == nil)
        #expect(engine.tick(at: 60).isEmpty)
        #expect(engine.result == .winners([p0]))
        // The next finger clears the pinned result and starts a new round.
        #expect(engine.fingerDown(p2, at: 61) == [.reset, .playerJoined(p2)])
    }

    @Test func pinnedResultIgnoresLateCancel() {
        var engine = engineWithResult()
        _ = engine.environmentChanged(at: 5)
        #expect(engine.cancelAllFingers(at: 5.1).isEmpty)
        #expect(engine.resetDeadline == nil)
        #expect(engine.dismissResult(at: 6) == [.reset])
    }

    @Test func systemCancelDuringResultSchedulesReset() {
        var engine = engineWithResult()
        #expect(engine.cancelAllFingers(at: 5) == [.playerLeft(p0), .playerLeft(p1)])
        #expect(engine.tick(at: 5.5) == [.reset])
    }

    @Test func configurationChangeDuringResultKeepsResult() {
        var engine = engineWithResult()
        #expect(engine.updateConfiguration(RoundConfiguration(minimumPlayers: 5), at: 5).isEmpty)
        #expect(engine.result != nil)
        #expect(engine.configuration.minimumPlayers == 5)
    }

    @Test func unknownFingerUpIsIgnored() {
        var engine = makeEngine()
        #expect(engine.fingerUp(p0, at: 0).isEmpty)
    }
}
