import Testing
@testable import FingerPickKit

struct IdleTimerPolicyTests {
    @Test func backgroundAlwaysAllowsAutoLock() {
        #expect(!IdleTimerPolicy.keepsScreenAwake(isForeground: false, hasFingers: true, isShowingResult: true, lastActivity: 0, now: 0))
    }

    @Test func fingersOrResultKeepScreenOn() {
        #expect(IdleTimerPolicy.keepsScreenAwake(isForeground: true, hasFingers: true, isShowingResult: false, lastActivity: 0, now: 999))
        #expect(IdleTimerPolicy.keepsScreenAwake(isForeground: true, hasFingers: false, isShowingResult: true, lastActivity: 0, now: 999))
    }

    @Test func waitingScreenStaysOnForTwoMinutesAfterLastTouch() {
        #expect(IdleTimerPolicy.keepsScreenAwake(isForeground: true, hasFingers: false, isShowingResult: false, lastActivity: 0, now: 119))
        #expect(!IdleTimerPolicy.keepsScreenAwake(isForeground: true, hasFingers: false, isShowingResult: false, lastActivity: 0, now: 120))
        #expect(!IdleTimerPolicy.keepsScreenAwake(isForeground: true, hasFingers: false, isShowingResult: false, lastActivity: nil, now: 0))
    }

    @Test func nextCheckIsAtTheTimeout() {
        #expect(IdleTimerPolicy.nextCheck(lastActivity: 10, now: 20) == 130)
        #expect(IdleTimerPolicy.nextCheck(lastActivity: 10, now: 200) == nil)
        #expect(IdleTimerPolicy.nextCheck(lastActivity: nil, now: 0) == nil)
    }
}
