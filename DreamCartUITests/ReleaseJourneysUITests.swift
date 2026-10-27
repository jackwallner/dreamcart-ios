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

    /// The core loop: pick a piece, add it to the cart, check out with coins,
    /// and own it. The wallet drops by exactly the piece's price, the piece is
    /// in the Closet, and both are still true after a relaunch.
    ///
    /// `-QAShopper` is the DEBUG seeded shopper (`QAShopper.swift`): the real
    /// catalog, a wallet and a closet, with checkout settled on the device.
    func testCoreLoopCheckoutChargesCoinsAndKeepsPieceInCloset() {
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.shop")
        QA.launch(app, arguments: ["-QAShopper", "-QAShopperReset"])
        today("core-today", in: app)
        let card = app.buttons.matching(productCard).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 30), "Today shows no product to open")
        let piece = Piece(card.label)
        XCTAssertGreaterThan(piece.price, 0, "could not read a price from \"\(card.label)\"")

        tapTab("Closet", in: app)
        let coinsBefore = wallet(in: app)
        let ownedBefore = ownedCount(in: app)
        XCTAssertLessThanOrEqual(piece.price, coinsBefore, "the seeded wallet cannot afford \(piece.name)")
        XCTAssertFalse(closetTile(piece.name, in: app).exists, "\(piece.name) is in the closet before it was bought")
        QA.checkpoint(app, "core-closet-before")

        tapTab("Today", in: app)
        reveal(card, in: app).tap()
        let buy = app.buttons["detailCheckoutButton"]
        XCTAssertTrue(buy.waitForExistence(timeout: 15), "the product detail has no Add to cart")
        XCTAssertTrue(buy.label.contains("Add to cart"), "the detail button reads \"\(buy.label)\" before adding")
        QA.checkpoint(app, "core-detail")
        buy.tap()
        XCTAssertTrue(wait(for: buy, labelContains: "Go to checkout"), "Add to cart did not put the piece in the cart")

        // Unfolded the Cart is a pane beside the detail; folded it is a tab
        // behind the pushed detail.
        let cartRow = app.buttons["Remove \(piece.name) from cart"]
        if !cartRow.waitForExistence(timeout: 3) {
            app.navigationBars.buttons["BackButton"].firstMatch.tap()
            tapTab("Cart", in: app)
        }
        XCTAssertTrue(cartRow.waitForExistence(timeout: 15), "\(piece.name) is not listed in the cart")
        XCTAssertTrue(app.descendants(matching: .any)["\(coinText(piece.price)) coins"].firstMatch.exists,
                      "the cart does not show the piece's price")
        QA.checkpoint(app, "core-cart")

        tap("cartCheckoutButton", in: app)
        let place = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Place order")).firstMatch
        XCTAssertTrue(place.waitForExistence(timeout: 15), "checkout never opened")
        XCTAssertTrue(app.staticTexts["1 item"].exists, "checkout does not count exactly one item")
        XCTAssertTrue(place.isEnabled, "Place order is disabled for an affordable piece with an address")
        QA.checkpoint(app, "core-checkout")
        place.tap()

        let skip = app.buttons["Skip to summary"]
        if skip.waitForExistence(timeout: 15) { skip.tap() }
        let haul = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "See in closet")).firstMatch
        XCTAssertTrue(haul.waitForExistence(timeout: 20), "the order never reached the haul summary")
        XCTAssertTrue(haul.label.contains("1 piece delivered to your closet"), "the haul reads \"\(haul.label)\"")
        XCTAssertTrue(haul.label.contains("\(coinText(piece.price)) coins"), "the haul does not show the price spent")
        QA.checkpoint(app, "core-haul")
        // The summary is one combined accessibility element; its button is the
        // last row, above the card's 28 pt bottom padding.
        haul.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1)).withOffset(CGVector(dx: 0, dy: -48)).tap()

        assertOwned(piece, coins: coinsBefore - piece.price, ownedBefore: ownedBefore, in: app)
        QA.checkpoint(app, "core-closet-after")

        app.launchArguments.removeAll { $0 == "-QAShopperReset" }
        QA.relaunch(app)
        today("core-today-after-relaunch", in: app)
        tapTab("Closet", in: app)
        assertOwned(piece, coins: coinsBefore - piece.price, ownedBefore: ownedBefore, in: app)
        QA.checkpoint(app, "core-closet-after-relaunch")
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

    private func checkpoint(_ name: String, button label: String, in app: XCUIApplication,
                            journey: String = #function) {
        XCTAssertTrue(app.buttons[label].firstMatch.waitForExistence(timeout: 15))
        QA.checkpoint(app, name, journey: journey)
    }

    /// Today has loaded once its tab is in the bar and the catalog has replaced the splash.
    private func today(_ name: String, in app: XCUIApplication, journey: String = #function) {
        XCTAssertTrue(app.buttons["Closet"].firstMatch.waitForExistence(timeout: 60))
        QA.checkpoint(app, name, journey: journey)
    }

    /// A product card reads "Brand, Name, 1,200 coins, Rare".
    private struct Piece {
        let name: String
        let price: Int

        init(_ label: String) {
            let parts = label.components(separatedBy: ", ")
            let priceIndex = parts.lastIndex { $0.hasSuffix(" coins") } ?? 0
            name = priceIndex > 0 ? parts[priceIndex - 1] : label
            price = priceIndex > 0 ? Int(parts[priceIndex].filter(\.isNumber)) ?? 0 : 0
        }
    }

    private let productCard = NSPredicate(format: "label MATCHES %@", ".+, [0-9,]+ coins, [A-Za-z]+")

    private func coinText(_ coins: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: coins)) ?? "\(coins)"
    }

    /// The balance on the wallet pill. Every mounted tab keeps its own pill,
    /// all showing the one balance, and the accessibility tree may hang the
    /// visible tab's pill on another tab's bar, so any of them will do.
    private func wallet(in app: XCUIApplication) -> Int {
        let pill = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Coin balance'")).firstMatch
        XCTAssertTrue(pill.waitForExistence(timeout: 15), "no wallet on screen")
        return Int(pill.label.filter(\.isNumber)) ?? -1
    }

    /// "13 pieces owned" from the Closet header, or nil where the header is
    /// left out (an unfolded pane).
    private func ownedCount(in app: XCUIApplication) -> Int? {
        let header = app.staticTexts.matching(NSPredicate(format: "label ENDSWITH ' owned'")).firstMatch
        return header.exists ? Int(header.label.filter(\.isNumber)) : nil
    }

    /// A Closet tile names the piece and, unlike a product card, no price.
    private func closetTile(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND NOT label CONTAINS ' coins' AND NOT label BEGINSWITH 'Remove '",
                                         name)).firstMatch
    }

    private func assertOwned(_ piece: Piece, coins: Int, ownedBefore: Int?, in app: XCUIApplication,
                             file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.navigationBars["Closet"].waitForExistence(timeout: 15), "the Closet is not open",
                      file: file, line: line)
        XCTAssertTrue(closetTile(piece.name, in: app).waitForExistence(timeout: 15),
                      "\(piece.name) is not in the closet", file: file, line: line)
        XCTAssertEqual(wallet(in: app), coins, "the wallet was not charged exactly the piece's price",
                       file: file, line: line)
        let shot = XCTAttachment(screenshot: app.screenshot())  // TEMP
        shot.lifetime = .keepAlways
        add(shot)
        if let ownedBefore, let ownedNow = ownedCount(in: app) {
            XCTAssertEqual(ownedNow, ownedBefore + 1, "the closet did not gain exactly one piece", file: file, line: line)
        }
    }

    private func wait(for element: XCUIElement, labelContains text: String, timeout: TimeInterval = 10) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)],
                                timeout: timeout) == .completed
    }

    /// Scrolls until the element can be tapped (AX3 pushes the Just dropped
    /// shelf below the fold).
    @discardableResult
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) -> XCUIElement {
        XCTAssertTrue(element.waitForExistence(timeout: 15))
        var tries = 0
        while !element.isHittable && tries < 6 {
            app.swipeUp()
            tries += 1
        }
        return element
    }
}
