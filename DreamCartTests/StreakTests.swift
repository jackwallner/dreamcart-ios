import Foundation
import XCTest

/// What the streak flame shows. The server only resets `streak` when the next
/// claim lands, so after a missed day `me()` still reports the old count while
/// claiming now starts a new streak at 1.
final class StreakTests: XCTestCase {
    /// 2026-10-31 12:00 UTC.
    private let now = Date(timeIntervalSince1970: 1_793_448_000)

    private func snapshot(streak: Int, lastClaim: String?) -> MeSnapshot {
        MeSnapshot(id: "u1", displayName: "Test", coins: 100, streak: streak, bestStreak: 9,
                   isPlus: false, lifetimeSpent: 0, itemsOwned: 0, canClaimDaily: true,
                   canSpin: true, lastDailyClaim: lastClaim, lastSpinDate: nil)
    }

    func testStreakClaimedYesterdayIsStillAlive() {
        XCTAssertEqual(snapshot(streak: 5, lastClaim: "2026-10-30").liveStreak(now: now), 5)
    }

    func testStreakClaimedTodayIsAlive() {
        XCTAssertEqual(snapshot(streak: 5, lastClaim: "2026-10-31").liveStreak(now: now), 5)
    }

    /// Three missed days: the card used to say "5 days" and "keep your streak
    /// alive" over a claim that starts again at 1.
    func testStreakThatLapsedIsGone() {
        XCTAssertEqual(snapshot(streak: 5, lastClaim: "2026-10-28").liveStreak(now: now), 0)
    }

    func testOneMissedDayEndsTheStreak() {
        XCTAssertEqual(snapshot(streak: 5, lastClaim: "2026-10-29").liveStreak(now: now), 0)
    }

    func testNeverClaimedHasNoStreak() {
        XCTAssertEqual(snapshot(streak: 0, lastClaim: nil).liveStreak(now: now), 0)
    }

    /// The day is the server's: UTC, whatever the phone's time zone says.
    func testTheDayRollsOverAtUTCMidnight() {
        let justAfterUTCMidnight = Date(timeIntervalSince1970: 1_793_491_260) // 2026-11-01 00:01 UTC
        XCTAssertEqual(snapshot(streak: 5, lastClaim: "2026-10-31").liveStreak(now: justAfterUTCMidnight), 5)
        XCTAssertEqual(snapshot(streak: 5, lastClaim: "2026-10-30").liveStreak(now: justAfterUTCMidnight), 0)
    }
}
