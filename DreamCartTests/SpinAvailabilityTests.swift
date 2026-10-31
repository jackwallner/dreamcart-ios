import XCTest

/// The wheel's once-a-day limit and DreamCart+ lifting it. `me()` only answers
/// "have you spun today?"; the server's `spin()` is what waives the limit for a
/// member, so the app has to know that itself or the membership's "spin as
/// often as you like" never shows up on the wheel.
@MainActor
final class SpinAvailabilityTests: XCTestCase {
    private func snapshot(canSpin: Bool, isPlus: Bool) -> MeSnapshot {
        MeSnapshot(id: "u1", displayName: "Test", coins: 100, streak: 0, bestStreak: 0,
                   isPlus: isPlus, lifetimeSpent: 0, itemsOwned: 0, canClaimDaily: false,
                   canSpin: canSpin, lastDailyClaim: nil, lastSpinDate: nil)
    }

    func testFreeSpinReadyCanSpin() {
        let shop = ShopStore()
        shop.me = snapshot(canSpin: true, isPlus: false)
        XCTAssertTrue(shop.canSpin)
    }

    func testNonMemberWhoSpunTodayCannotSpinAgain() {
        let shop = ShopStore()
        shop.me = snapshot(canSpin: false, isPlus: false)
        XCTAssertFalse(shop.canSpin)
    }

    func testMemberWhoSpunTodayCanSpinAgain() {
        let shop = ShopStore()
        shop.me = snapshot(canSpin: false, isPlus: true)
        XCTAssertTrue(shop.canSpin)
    }

    func testNoProfileMeansNoSpin() {
        XCTAssertFalse(ShopStore().canSpin)
    }
}
