import XCTest

/// Captures the DreamCart+ purchase screen for App Store Review.
///
/// App Review will not approve a subscription without a screenshot of the
/// screen that sells it, and that screenshot has to show the real price and the
/// real trial terms. `xcrun simctl` cannot supply either: StoreKit Testing is
/// applied by the *scheme*, so a plain simulator launch renders the no-price
/// fallback. Running here, under the DreamCartUITests scheme's
/// `storeKitConfiguration`, the paywall asks a real store and gets $0.99 and
/// the 3-day introductory offer back.
///
/// `DREAMCART_PLUS_SHOT` renders the paywall directly instead of the root view,
/// because reaching it normally needs a brand-new account and a full onboarding
/// run.
///
/// Output: the attachment named `plus_weekly` in the .xcresult. Pull it with
/// `scripts/capture-plus-paywall.sh`, which drives this test and extracts it.
final class PlusPaywallScreenshotTests: XCTestCase {

    func testCapturePlusPaywall() {
        let app = XCUIApplication()
        app.launchEnvironment["DREAMCART_PLUS_SHOT"] = "1"
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 30)

        // Wait for the price to arrive rather than sleeping a fixed amount: a
        // screenshot taken before StoreKit answers shows the fallback copy and
        // is exactly the screenshot App Review would reject.
        let priced = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "per week")
        ).firstMatch
        let arrived = priced.waitForExistence(timeout: 25)
        XCTAssertTrue(arrived, "paywall never showed a real weekly price; StoreKit config not applied?")

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "plus_weekly"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
