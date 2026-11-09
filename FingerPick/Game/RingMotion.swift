import SwiftUI

/// Ring motion: springs, pulses and shakes, all switched to fades under Reduce Motion.
extension RingFrame {
    /// A finger landing: the ring springs up from 0.4, overshoots slightly and settles.
    func scaleIn(age: TimeInterval) -> CGFloat {
        guard !reduceMotion else { return 1 }
        return 0.4 + 0.6 * Self.spring(age)
    }

    /// Damped spring from 0 to 1 with a small overshoot (about 6%), settled by 0.6 s.
    static func spring(_ t: TimeInterval) -> CGFloat {
        guard t > 0 else { return 0 }
        guard t < 0.6 else { return 1 }
        return 1 - exp(-8 * t) * cos(11 * t)
    }

    /// Rises from 0 to 1 and back over `duration`; 0 outside it.
    static func bump(_ t: TimeInterval, duration: TimeInterval) -> CGFloat {
        guard t > 0, t < duration else { return 0 }
        return sin(.pi * t / duration)
    }

    /// Subtle idle pulse; during the countdown every ring pulses together once a second.
    var pulse: CGFloat {
        guard !reduceMotion else { return 1 }
        if let elapsed = countdownElapsed {
            let phase = elapsed - elapsed.rounded(.down)
            return 1 + 0.08 * pow(1 - phase, 2)
        }
        return 1 + 0.03 * sin(2 * .pi * now / 1.6)
    }

    /// Brief horizontal shake when the countdown is cancelled.
    var shake: CGFloat {
        guard !reduceMotion, let age = cancelAge, age < 0.4 else { return 0 }
        return 8 * sin(age * 50) * (1 - age / 0.4)
    }

    /// Reduce Motion alternative to the shake: rings dim briefly when the countdown is cancelled.
    var cancelFlash: Double {
        guard let age = cancelAge, age < 0.4 else { return 1 }
        return 0.4 + 0.6 * age / 0.4
    }
}
