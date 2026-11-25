import XCTest

/// Ask to Buy: RevenueCat's pending error reads as waiting for approval, never
/// as a failure, and the notice belongs to the purchase screen that raised it.
@MainActor
final class PurchaseIssueTests: XCTestCase {
    func testPaymentPendingIsWaitingForApproval() {
        XCTAssertEqual(PurchaseIssue.from(revenueCatCode: 20, description: "The payment is pending."), .awaitingApproval)
    }

    func testOtherErrorsKeepTheirOwnDescription() {
        // networkError (10), offlineConnectionError (35), purchaseNotAllowedError (6):
        // the app has no translated "App Store isn't reachable" line, so they stay as they were.
        for code in [10, 35, 6] {
            XCTAssertEqual(PurchaseIssue.from(revenueCatCode: code, description: "Offline."), .failed("Offline."))
        }
        XCTAssertEqual(PurchaseIssue.from(revenueCatCode: nil, description: "Other."), .failed("Other."))
    }

    func testThePendingMessageIsCalmCopy() {
        XCTAssertEqual(PurchaseIssue.awaitingApprovalMessage,
                       "Waiting for approval. Your purchase unlocks once it is approved.")
    }

    func testPendingShowsTheNoticeAndNoError() {
        let store = StoreController()
        store.lastError = "Earlier error"
        store.show(.awaitingApproval)
        XCTAssertTrue(store.awaitingApproval)
        XCTAssertNil(store.lastError)
        XCTAssertFalse(store.isPurchasing, "the button is not left spinning")
    }

    func testAFailureAfterPendingReplacesTheNotice() {
        let store = StoreController()
        store.show(.awaitingApproval)
        store.show(.failed("Declined."))
        XCTAssertFalse(store.awaitingApproval)
        XCTAssertEqual(store.lastError, "Declined.")
    }

    /// The pending flag must not outlive the screen that raised it, and an
    /// error from one purchase screen is not shown on the next one.
    func testClosingThePurchaseScreenClearsTheNoticeAndTheError() {
        let store = StoreController()
        store.show(.awaitingApproval)
        store.purchaseScreenClosed()
        XCTAssertFalse(store.awaitingApproval)

        store.show(.failed("No previous membership."))
        store.purchaseScreenClosed()
        XCTAssertNil(store.lastError)
    }
}
