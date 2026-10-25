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
        // The DreamCart+ row sits below the fold of the You tab.
        let plus = app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", "DreamCart+")).firstMatch
        var swipes = 0
        while !(plus.exists && plus.isHittable) && swipes < 8 {
            app.swipeUp()
            swipes += 1
        }
        plus.tap()
        let priced = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "per week")).firstMatch
        XCTAssertTrue(priced.waitForExistence(timeout: 25))
        QA.checkpoint(app, "plus-offer", paywall: true)
        tap("Maybe later", in: app)
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
