import XCTest

@MainActor
final class ReleaseJourneysUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func test1FirstRunToBrowsing() {
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.shop")
        QA.launch(app)
        checkpoint("welcome", button: "Next", in: app)
        tap("Next", in: app)
        checkpoint("welcome-coins", button: "Next", in: app)
        tap("Next", in: app)
        checkpoint("welcome-closet", button: "Get started", in: app)
        tap("Get started", in: app)
        checkpoint("sign-in", button: "Browse without an account", in: app)
        tap("Browse without an account", in: app)
        today("first-today", in: app)
    }

    func test2TabsPlusOfferAndReturn() {
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.shop")
        QA.launch(app, arguments: ["-DuoSeed"])
        today("today", in: app)
        for tab in ["For You", "Cart", "Closet", "You"] {
            tapTab(tab, in: app)
            QA.checkpoint(app, tab.lowercased().replacingOccurrences(of: " ", with: "-"))
        }
        // The Duo seed is already a DreamCart+ member (its row opens the App
        // Store), so the purchase screen here is the coin shop, one row below.
        // Every tab stays mounted, so Cart has its own "Get more coins" button;
        // the identifier picks the one on You.
        let coins = app.buttons["profile.get-coins"].firstMatch
        var swipes = 0
        // isHittable is true for rows below the fold, so scroll until the row
        // sits above the floating tab bar.
        let visibleBottom = app.windows.firstMatch.frame.maxY - 140
        while !(coins.exists && coins.frame.maxY < visibleBottom) && swipes < 8 {
            app.swipeUp()
            swipes += 1
        }
        // A tap while the swipe is still coasting only stops the scroll.
        if swipes > 0 { sleep(2) }
        coins.tap()
        let balance = app.staticTexts["Your balance"]
        if !balance.waitForExistence(timeout: 8) { coins.tap() }
        XCTAssertTrue(balance.waitForExistence(timeout: 25))
        QA.checkpoint(app, "coin-shop", paywall: true)
        tap("Done", in: app)
        tapTab("Today", in: app)
        today("today-after-offer", in: app)
        QA.interrupt(app)
        today("today-after-background", in: app)
        QA.relaunch(app)
        today("today-after-relaunch", in: app)
    }

    private func tap(_ label: String, in app: XCUIApplication) {
        let button = app.buttons[label].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 15))
        button.tap()
    }

    private func tapTab(_ label: String, in app: XCUIApplication) {
        let button = app.buttons[label].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 15))
        button.tap()
    }

    private func checkpoint(_ name: String, button label: String, in app: XCUIApplication) {
        XCTAssertTrue(app.buttons[label].firstMatch.waitForExistence(timeout: 15))
        QA.checkpoint(app, name)
    }

    /// Today has loaded once its tab is in the bar and the catalog has replaced the splash.
    private func today(_ name: String, in app: XCUIApplication) {
        XCTAssertTrue(app.buttons["Closet"].firstMatch.waitForExistence(timeout: 60))
        QA.checkpoint(app, name)
    }
}
