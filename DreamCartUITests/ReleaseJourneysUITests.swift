import XCTest

@MainActor
final class ReleaseJourneysUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func test1FirstRunToBrowsing() {
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.shop")
        // A reinstall keeps the Keychain session, so ask for a clean first run.
        QA.launch(app, arguments: ["-FreshInstall"])
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
        // Store), so the purchase screen here is the coin shop. The wallet pill
        // in the You bar opens it without scrolling; every tab stays mounted
        // with its own pill, so the bar picks the one on You.
        let pill = app.navigationBars["You"].buttons
            .matching(NSPredicate(format: "label BEGINSWITH 'Coin balance'")).firstMatch
        XCTAssertTrue(pill.waitForExistence(timeout: 15))
        pill.tap()
        XCTAssertTrue(app.staticTexts["Your balance"].waitForExistence(timeout: 25))
        QA.checkpoint(app, "coin-shop", paywall: true)
        tap("Done", in: app)
        tapTab("Today", in: app)
        today("today-after-offer", in: app)
        QA.interrupt(app)
        today("today-after-background", in: app)
        QA.relaunch(app)
        today("today-after-relaunch", in: app)
    }

    /// Core loop: sign in, add a piece, check out with coins, find it in the
    /// closet, and still own it after a relaunch.
    func testCoreLoopCheckoutAddsToCloset() {
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.shop")
        QA.launch(app, arguments: ["-FreshInstall"])
        checkpoint("core-welcome", button: "Next", in: app)
        tap("Next", in: app)
        tap("Next", in: app)
        tap("Get started", in: app)
        tap("Continue as tester", in: app)
        // A first sign-in is offered DreamCart+ before Today; decline it.
        let notNow = app.buttons["Not now"].firstMatch
        if notNow.waitForExistence(timeout: 20) { notNow.tap() }
        XCTAssertTrue(app.buttons["Closet"].firstMatch.waitForExistence(timeout: 60))
        tapTab("Closet", in: app)
        let before = ownedCount(app)
        QA.checkpoint(app, "core-closet-before")

        tapTab("For You", in: app)
        let add = app.buttons["Add to cart"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 60))
        add.tap()
        tapTab("Cart", in: app)
        let checkout = app.buttons["cartCheckoutButton"].firstMatch
        XCTAssertTrue(checkout.waitForExistence(timeout: 15), "cart has the piece and the shopper can afford it")
        QA.checkpoint(app, "core-cart")
        checkout.tap()

        let skip = app.buttons["Skip for now"].firstMatch
        if skip.waitForExistence(timeout: 15) { skip.tap() }
        let place = app.buttons["Place order"].firstMatch
        XCTAssertTrue(place.waitForExistence(timeout: 15))
        QA.checkpoint(app, "core-checkout")
        place.tap()

        let skipReveal = app.buttons["Skip to summary"].firstMatch
        if skipReveal.waitForExistence(timeout: 45) { skipReveal.tap() }
        let closet = app.buttons["See in closet"].firstMatch
        XCTAssertTrue(closet.waitForExistence(timeout: 45), "order placed and the haul summary shows")
        QA.checkpoint(app, "core-haul")
        closet.tap()
        XCTAssertEqual(ownedCount(app), before + 1, "closet gained the purchased piece")
        QA.checkpoint(app, "core-closet-after")

        // The relaunch keeps the session: only the first launch starts clean.
        app.launchArguments.removeAll { $0 == "-FreshInstall" }
        QA.relaunch(app)
        // Unsigned simulator builds (gh-sim) cannot write the Keychain, so the
        // session is gone after a relaunch there: sign in again. The purchase
        // itself lives on the server and must still be in the closet.
        let tester = app.buttons["Continue as tester"].firstMatch
        if tester.waitForExistence(timeout: 20) {
            tester.tap()
            let offer = app.buttons["Not now"].firstMatch
            if offer.waitForExistence(timeout: 20) { offer.tap() }
        }
        XCTAssertTrue(app.buttons["Closet"].firstMatch.waitForExistence(timeout: 60))
        tapTab("Closet", in: app)
        XCTAssertEqual(ownedCount(app), before + 1, "the purchase survives a relaunch")
        QA.checkpoint(app, "core-closet-after-relaunch")
    }

    /// Reads the closet's piece count: "N pieces owned" on the collection card,
    /// or "N pieces" under All pieces where the unfolded pane drops the card.
    private func ownedCount(_ app: XCUIApplication) -> Int {
        let count = app.staticTexts
            .matching(NSPredicate(format: "label MATCHES '^[0-9]+ pieces?( owned)?$'")).firstMatch
        let empty = app.staticTexts["Your closet is empty"]
        let deadline = Date().addingTimeInterval(30)
        while Date() < deadline, !count.exists, !empty.exists { _ = count.waitForExistence(timeout: 1) }
        if empty.exists { return 0 }
        XCTAssertTrue(count.exists, "the closet shows how many pieces are owned")
        return Int(count.label.prefix { $0.isNumber }) ?? -1
    }

    private func tap(_ label: String, in app: XCUIApplication) {
        let button = app.buttons[label].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 15))
        button.tap()
    }

    private func tapTab(_ label: String, in app: XCUIApplication) {
        // Unfolded (iPhone Duo) the Cart is a pane beside the browsing tabs and
        // has no tab button: it is already open.
        if label == "Cart", !app.buttons["Cart"].firstMatch.waitForExistence(timeout: 3) {
            XCTAssertTrue(app.navigationBars["Cart"].waitForExistence(timeout: 15))
            return
        }
        let button = app.buttons[label].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 15))
        button.tap()
    }

    private func checkpoint(_ name: String, button label: String, in app: XCUIApplication) {
        // The first launch loads the catalog before the welcome pages show.
        XCTAssertTrue(app.buttons[label].firstMatch.waitForExistence(timeout: 60))
        QA.checkpoint(app, name)
    }

    /// Today has loaded once its tab is in the bar and the catalog has replaced the splash.
    private func today(_ name: String, in app: XCUIApplication) {
        XCTAssertTrue(app.buttons["Closet"].firstMatch.waitForExistence(timeout: 60))
        QA.checkpoint(app, name)
    }
}
