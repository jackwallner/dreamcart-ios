import Foundation
import XCTest

@MainActor
final class PurchaseRecoveryTests: XCTestCase {
    private func makeRecovery() -> (PurchaseRecovery, UserDefaults) {
        let defaults = UserDefaults(suiteName: "PurchaseRecoveryTests.\(UUID().uuidString)")!
        let recovery = PurchaseRecovery(defaults: defaults)
        recovery.selectAccount("buyer")
        return (recovery, defaults)
    }

    func testMembershipWaitsForRefreshedPlusWithBoundedRetry() async {
        let (recovery, _) = makeRecovery()
        recovery.beginPlus(accountId: "buyer")
        var refreshes = 0
        await recovery.reconcile(pause: {}, redeem: {}, refreshPlus: {
            refreshes += 1
            return false
        }, delivered: { _ in false })
        XCTAssertEqual(refreshes, 3)
        XCTAssertTrue(recovery.pendingPlus)
        XCTAssertFalse(recovery.confirmedPlus)
        XCTAssertFalse(recovery.isRecovering)

        await recovery.reconcile(pause: {}, redeem: {}, refreshPlus: { true }, delivered: { _ in false })
        XCTAssertFalse(recovery.pendingPlus)
        XCTAssertTrue(recovery.confirmedPlus)
    }

    func testProfileFailureRemainsPendingAndSurfacesErrorUntilRetry() async {
        let (recovery, _) = makeRecovery()
        recovery.beginPlus(accountId: "buyer")
        await recovery.reconcile(pause: {}, redeem: {}, refreshPlus: {
            throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Offline"])
        }, delivered: { _ in false })
        XCTAssertTrue(recovery.pendingPlus)
        XCTAssertEqual(recovery.lastError, "Offline")
        await recovery.reconcile(pause: {}, redeem: {}, refreshPlus: { true }, delivered: { _ in false })
        XCTAssertFalse(recovery.pendingPlus)
        XCTAssertNil(recovery.lastError)
    }

    func testDelayedCoinsPersistAcrossRelaunchAndAccountSwitchUntilGrantConfirmed() async {
        let (recovery, defaults) = makeRecovery()
        let delivery = PendingCoinDelivery(productId: "pack", coins: 1000, afterLedgerId: 42)
        recovery.beginCoins(delivery, accountId: "buyer")
        await recovery.reconcile(pause: {}, redeem: {}, refreshPlus: { false }, delivered: { _ in false })
        XCTAssertEqual(recovery.pendingCoins, delivery)
        XCTAssertNil(recovery.lastDeliveredCoins)

        let relaunched = PurchaseRecovery(defaults: defaults)
        relaunched.selectAccount("someone-else")
        XCTAssertFalse(relaunched.hasPending)
        relaunched.selectAccount("buyer")
        XCTAssertEqual(relaunched.pendingCoins, delivery)
        var grantsChecked = 0
        await relaunched.reconcile(pause: {}, redeem: {}, refreshPlus: { false }, delivered: { pending in
            XCTAssertEqual(pending.afterLedgerId, 42)
            grantsChecked += 1
            return grantsChecked == 2
        })
        XCTAssertEqual(grantsChecked, 2)
        XCTAssertNil(relaunched.pendingCoins)
        XCTAssertEqual(relaunched.lastDeliveredCoins, delivery)
        let finished = PurchaseRecovery(defaults: defaults)
        finished.selectAccount("buyer")
        XCTAssertFalse(finished.hasPending)
    }

    func testReconciliationFailureIsVisibleAndDoesNotClearPaidCoins() async {
        let (recovery, _) = makeRecovery()
        recovery.beginCoins(PendingCoinDelivery(productId: "pack", coins: 1000, afterLedgerId: 1), accountId: "buyer")
        await recovery.reconcile(pause: {}, redeem: {
            throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Delivery unavailable"])
        }, refreshPlus: { XCTFail("A failed reconciliation must not confirm delivery"); return false }, delivered: { _ in true })
        XCTAssertNotNil(recovery.pendingCoins)
        XCTAssertEqual(recovery.lastError, "Delivery unavailable")
        XCTAssertFalse(recovery.isRecovering)
    }

    func testSuccessArrivingAfterSignOutStaysWithPurchasingAccount() {
        let (recovery, defaults) = makeRecovery()
        recovery.selectAccount("someone-else")
        recovery.beginPlus(accountId: "buyer")
        recovery.beginCoins(PendingCoinDelivery(productId: "pack", coins: 1000, afterLedgerId: 1), accountId: "buyer")
        XCTAssertFalse(recovery.hasPending)
        let relaunched = PurchaseRecovery(defaults: defaults)
        relaunched.selectAccount("buyer")
        XCTAssertTrue(relaunched.pendingPlus)
        XCTAssertNotNil(relaunched.pendingCoins)
    }

    func testAccountSwitchDoesNotAnnounceDelivery() async {
        let (recovery, _) = makeRecovery()
        recovery.beginPlus(accountId: "buyer")
        recovery.beginCoins(PendingCoinDelivery(productId: "pack", coins: 1000, afterLedgerId: 1), accountId: "buyer")
        await recovery.reconcile(pause: {}, redeem: {}, refreshPlus: {
            recovery.selectAccount("someone-else")
            return true
        }, delivered: { _ in true })
        XCTAssertFalse(recovery.confirmedPlus)
        XCTAssertNil(recovery.lastDeliveredCoins)
        recovery.selectAccount("buyer")
        XCTAssertTrue(recovery.pendingPlus)
        XCTAssertNotNil(recovery.pendingCoins)
    }
}
