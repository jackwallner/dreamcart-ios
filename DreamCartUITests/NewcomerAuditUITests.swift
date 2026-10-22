import XCTest

/// Persona audit walk for a first-time user who does not know the app's words
/// ("drop", "closet", "coins") and wants one useful result right away.
///
/// Every step attaches a named screenshot (lifetime keepAlways) and logs the
/// elapsed time since launch. Nothing here asserts on UX quality; it records
/// what a newcomer sees. Frame rate is not measured.
final class NewcomerAuditUITests: XCTestCase {

    private var started = Date()

    /// Forces the onboarding slides and the sign-in choice, whatever an earlier test left behind.
    private static let freshInstall = ["-hasCompletedOnboarding", "NO", "-dreamcart.browsingAsGuest", "NO"]

    override func setUp() {
        continueAfterFailure = true
    }

    private func launch(_ args: [String] = [], env: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.shop")
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"] + args
        env.forEach { app.launchEnvironment[$0.key] = $0.value }
        started = Date()
        app.launch()
        return app
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
        let t = String(format: "%.1f", Date().timeIntervalSince(started))
        NSLog("AUDIT shot %@ t=%@s", name, t)
    }

    private func note(_ text: String) {
        NSLog("AUDIT note %@", text)
    }

    private func tab(_ app: XCUIApplication, _ name: String) {
        let b = app.buttons[name].firstMatch
        if b.waitForExistence(timeout: 10) { b.tap() } else { note("tab \(name) not found") }
    }

    /// First product card on screen (cards are buttons whose label carries a price).
    private func firstProduct(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'coins'")).firstMatch
    }

    // MARK: guest first run

    func testGuestFirstRun() {
        let app = launch(Self.freshInstall)
        // Splash is up until the first catalog load finishes.
        shot(app, "01-splash")
        let next = app.buttons["Next"]
        let reachedWelcome = next.waitForExistence(timeout: 30)
        note("welcome after \(Date().timeIntervalSince(started))s reached=\(reachedWelcome)")
        shot(app, "02-welcome-1")
        next.tap()
        shot(app, "03-welcome-2")
        app.buttons["Next"].tap()
        shot(app, "04-welcome-3")
        app.buttons["Get started"].tap()
        sleep(1)
        shot(app, "05-signin-screen")
        let browse = app.buttons["Browse without an account"]
        XCTAssertTrue(browse.waitForExistence(timeout: 10))
        note("browse button frame \(browse.frame)")
        browse.tap()
        shot(app, "06-after-browse-splash")

        // Today, as a guest.
        let loaded = app.buttons["See all brands"].waitForExistence(timeout: 60)
            || app.staticTexts["Just dropped"].waitForExistence(timeout: 5)
        note("today loaded after \(Date().timeIntervalSince(started))s ok=\(loaded)")
        shot(app, "10-today-guest")
        app.swipeUp()
        shot(app, "11-today-guest-scrolled")
        app.swipeDown()
        app.swipeDown()

        // Open a product, try to add it.
        let card = firstProduct(app)
        if card.waitForExistence(timeout: 30) {
            note("first card label: \(card.label)")
            card.tap()
            sleep(2)
            shot(app, "12-product-detail")
            let add = app.buttons["Add to cart"].firstMatch
            if add.waitForExistence(timeout: 10) {
                add.tap()
                sleep(1)
                shot(app, "13-add-to-cart-guest-signin-sheet")
                let notNow = app.buttons["Not now"]
                if notNow.waitForExistence(timeout: 5) { notNow.tap() }
            } else {
                note("Add to cart button not found")
            }
            sleep(1)
            let fav = app.buttons["Add to favorites"].firstMatch
            if fav.exists {
                fav.tap()
                sleep(1)
                shot(app, "14-favorite-guest-signin-sheet")
                if app.buttons["Not now"].waitForExistence(timeout: 5) { app.buttons["Not now"].tap() }
            }
            app.navigationBars.buttons.firstMatch.tap()
        } else {
            note("no product card with coins label found")
        }

        // Wallet slot as a guest.
        let signIn = app.buttons["Sign in"].firstMatch
        note("wallet slot shows Sign in: \(signIn.exists)")

        // Shop all.
        app.swipeUp()
        let shopAll = app.buttons["Shop all"].firstMatch
        if shopAll.waitForExistence(timeout: 5) {
            shopAll.tap()
            sleep(2)
            shot(app, "20-shop")
            let search = app.searchFields.firstMatch
            if search.waitForExistence(timeout: 5) {
                search.tap()
                search.typeText("black")
                sleep(2)
                shot(app, "21-shop-search-black")
                app.buttons["Cancel"].firstMatch.tap()
            }
            let chip = app.buttons["Shoes"].firstMatch
            if chip.exists { chip.tap(); sleep(1); shot(app, "22-shop-shoes") }
            app.navigationBars.buttons.firstMatch.tap()
        } else {
            note("Shop all button not found on Today scroll position")
            shot(app, "20-no-shop-all")
        }

        // Every other tab as a guest.
        for name in ["For You", "Cart", "Closet", "You"] {
            tab(app, name)
            sleep(2)
            shot(app, "30-tab-\(name.replacingOccurrences(of: " ", with: ""))-guest")
        }

        // For You: swipe right as guest.
        tab(app, "For You")
        sleep(2)
        let add = app.buttons["Add to cart"].firstMatch
        if add.waitForExistence(timeout: 10) {
            add.tap()
            sleep(2)
            shot(app, "31-foryou-addtocart-guest")
            if app.buttons["Not now"].waitForExistence(timeout: 5) { app.buttons["Not now"].tap() }
            sleep(1)
            shot(app, "32-foryou-after-dismiss")
        }
    }

    // MARK: signed-in newcomer (seeded locally, no server session)

    func testFreshSignedInShopper() {
        let app = launch(["-DuoSeed", "-DuoFresh"])
        let ready = app.staticTexts["Your coins are waiting"].waitForExistence(timeout: 60)
        note("today ready after \(Date().timeIntervalSince(started))s ok=\(ready)")
        shot(app, "40-today-fresh")
        app.swipeUp()
        shot(app, "41-today-fresh-scrolled")
        app.swipeDown()
        app.swipeDown()

        // Wallet pill.
        let wallet = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Coin balance'")).firstMatch
        if wallet.waitForExistence(timeout: 5) {
            note("wallet label: \(wallet.label) frame \(wallet.frame)")
            wallet.tap()
            sleep(2)
            shot(app, "42-coin-shop")
            let close = app.buttons["Close"].firstMatch
            if close.exists { close.tap() } else { app.swipeDown() }
            sleep(1)
        }

        // Spin card.
        let spin = app.buttons["Spin the wheel"].firstMatch
        if spin.waitForExistence(timeout: 5) || app.staticTexts["Spin the wheel"].exists {
            (spin.exists ? spin : app.staticTexts["Spin the wheel"]).tap()
            sleep(2)
            shot(app, "43-spin")
            let close = app.buttons["Close"].firstMatch
            if close.exists { close.tap() }
            sleep(1)
        } else {
            note("spin card not found")
        }

        // Product -> add -> checkout.
        let card = firstProduct(app)
        if card.waitForExistence(timeout: 30) {
            note("first card label: \(card.label)")
            card.tap()
            sleep(2)
            shot(app, "44-product-detail-signed-in")
            let add = app.buttons["Add to cart"].firstMatch
            if add.waitForExistence(timeout: 5) {
                add.tap()
                sleep(1)
                shot(app, "45-added-to-cart")
                let go = app.buttons["detailCheckoutButton"]
                note("button after add: \(go.label)")
            }
            app.navigationBars.buttons.firstMatch.tap()
        }
        tab(app, "Cart")
        sleep(2)
        shot(app, "46-cart")
        let checkout = app.buttons["cartCheckoutButton"]
        if checkout.waitForExistence(timeout: 5) {
            checkout.tap()
            sleep(2)
            shot(app, "47-checkout")
            let skip = app.buttons["Skip for now"]
            if skip.exists { skip.tap(); sleep(1); shot(app, "48-checkout-skipped") }
            app.buttons["Cancel"].firstMatch.tap()
        } else {
            note("cart checkout button not found")
        }

        for name in ["For You", "Closet", "You"] {
            tab(app, name)
            sleep(2)
            shot(app, "50-tab-\(name.replacingOccurrences(of: " ", with: ""))-fresh")
        }
    }

    // MARK: onboarding DreamCart+ offer

    func testPlusOfferNewcomer() {
        let app = launch(env: ["DREAMCART_PLUS_SHOT": "1"])
        _ = app.buttons["Not now"].waitForExistence(timeout: 30)
        sleep(3)
        shot(app, "60-plus-offer")
    }

    // MARK: large text

    func testFirstRunLargeText() {
        let app = launch(Self.freshInstall + ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"])
        let next = app.buttons["Next"]
        guard next.waitForExistence(timeout: 30) else { return note("welcome never appeared") }
        shot(app, "70-welcome-ax-large")
        next.tap(); app.buttons["Next"].tap()
        shot(app, "71-welcome3-ax-large")
        app.buttons["Get started"].tap()
        sleep(1)
        shot(app, "72-signin-ax-large")
        let browse = app.buttons["Browse without an account"]
        note("browse button visible without scroll: \(browse.isHittable)")
        if !browse.isHittable { app.swipeUp() }
        shot(app, "73-signin-ax-large-scrolled")
        if browse.waitForExistence(timeout: 5), browse.isHittable { browse.tap() }
        _ = app.staticTexts["Just dropped"].waitForExistence(timeout: 60)
        shot(app, "74-today-ax-large")
    }
}
