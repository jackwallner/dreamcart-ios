import XCTest

/// Walks the repeat-use loop of an experienced shopper on the DEBUG `-DuoSeed`
/// fixture: a signed-in local shopper (real public catalog, 18,450 coins, a
/// three piece cart, a twelve piece closet, daily claimed, spin ready). Nothing
/// is written to Supabase, RevenueCat is not configured and analytics stay off.
///
/// Every step attaches a screenshot, and `notes` attaches the measured facts
/// (hit target sizes, tap counts, element presence) so the audit report can
/// separate runtime observation from source reading.
final class ExperiencedShopperAuditUITests: XCTestCase {
    private var app: XCUIApplication!
    private var notes: [String] = []

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication(bundleIdentifier: "com.jackwallner.shop")
        app.launchArguments += ["-DuoSeed"]
    }

    override func tearDown() {
        let text = XCTAttachment(string: notes.joined(separator: "\n"))
        text.name = "notes"
        text.lifetime = .keepAlways
        add(text)
    }

    // MARK: helpers

    private func shot(_ name: String) {
        let s = XCTAttachment(screenshot: app.screenshot())
        s.name = name
        s.lifetime = .keepAlways
        add(s)
    }

    private func note(_ line: String) { notes.append(line) }

    private func size(_ name: String, _ element: XCUIElement) {
        guard element.exists else { note("SIZE \(name): not found"); return }
        let f = element.frame
        note("SIZE \(name): \(Int(f.width))x\(Int(f.height)) hittable=\(element.isHittable)")
    }

    private func launch() {
        app.launch()
        // Splash holds until the first catalog load finishes.
        let tab = app.buttons["Closet"]
        XCTAssertTrue(tab.waitForExistence(timeout: 90), "tab bar never appeared (catalog load?)")
        sleep(3)
    }

    private func tab(_ name: String) {
        app.buttons[name].tap()
        sleep(1)
    }

    private func firstProduct() -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS ' coins,'")).firstMatch
    }

    // MARK: flows

    func testTodayAndSpin() {
        launch()
        shot("today_top")
        size("wallet_pill", app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Coin balance'")).firstMatch)
        note("PRESENT daily_claimed_chip=\(app.staticTexts['Daily claimed'].exists)")
        note("PRESENT just_dropped=\(app.staticTexts['Just dropped'].exists)")
        for name in ["Today", "For You", "Cart", "Closet", "You"] { size("tab_\(name)", app.buttons[name]) }

        app.swipeUp()
        sleep(1)
        shot("today_scrolled")
        app.swipeDown(); app.swipeDown()
        sleep(1)

        let spin = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Spin the wheel'")).firstMatch
        XCTAssertTrue(spin.waitForExistence(timeout: 10), "spin card missing")
        spin.tap()
        sleep(2)
        shot("spin_sheet")
        note("PRESENT spin_button=\(app.buttons['Spin'].exists) close=\(app.buttons['Close'].exists)")
        size("spin_close", app.buttons["Close"])
    }

    func testShopBrowseAndAddToCart() {
        launch()
        let shopAll = app.buttons["Shop all"]
        XCTAssertTrue(shopAll.waitForExistence(timeout: 10), "Shop all missing")
        size("shop_all", shopAll)
        shopAll.tap()
        sleep(3)
        shot("shop_all")
        note("PRESENT shop_sort_control=\(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'sort'")).count > 0)")
        note("PRESENT shop_owned_filter=\(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'owned'")).count > 0)")
        size("chip_Shoes", app.buttons["Shoes"])
        app.buttons["Shoes"].tap()
        sleep(2)
        shot("shop_shoes")

        // Search while a category chip is selected.
        let search = app.searchFields.firstMatch
        if search.waitForExistence(timeout: 5) {
            search.tap()
            search.typeText("black")
            sleep(2)
            shot("shop_search_black_with_shoes_chip")
            note("SEARCH_WITH_CHIP chip_hidden=\(!app.buttons["Shoes"].exists)")
            if app.buttons["Cancel"].exists { app.buttons["Cancel"].tap() }
        } else {
            note("PRESENT search_field=false")
        }
        sleep(1)

        let product = firstProduct()
        XCTAssertTrue(product.waitForExistence(timeout: 10), "no product card")
        product.tap()
        sleep(3)
        shot("detail_before_add")
        note("DETAIL tab_bar_visible=\(app.buttons["Closet"].isHittable)")
        let add = app.buttons["Add to cart"]
        XCTAssertTrue(add.waitForExistence(timeout: 10), "Add to cart missing")
        size("add_to_cart", add)
        add.tap()
        sleep(1)
        shot("detail_after_add_1s")
        note("DETAIL_AFTER_ADD button_now_go_to_checkout=\(app.buttons["Go to checkout"].exists)")
        note("DETAIL_AFTER_ADD cart_count_visible_on_detail=\(app.buttons["Cart"].exists && app.buttons["Cart"].isHittable)")
        size("favorite", app.buttons.matching(NSPredicate(format: "label CONTAINS 'favorites'")).firstMatch)
    }

    func testCartAndCheckout() {
        launch()
        tab("Cart")
        shot("cart_seeded")
        note("CART badge/items label=\(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'item'")).firstMatch.label)")
        let remove = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Remove '")).firstMatch
        size("cart_remove", remove)

        // Tapping a row (not the X): does it open the piece?
        let firstRowText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Blazer' OR label CONTAINS[c] 'Loafers' OR label CONTAINS[c] 'Heels'")).firstMatch
        if firstRowText.exists {
            firstRowText.tap()
            sleep(2)
            note("CART_ROW_TAP opens_detail=\(app.buttons["Add to cart"].exists || app.buttons["Go to checkout"].exists)")
            shot("cart_row_tap_result")
            if app.navigationBars.buttons.firstMatch.exists, !app.buttons["Check out"].exists {
                app.navigationBars.buttons.firstMatch.tap()
                sleep(1)
            }
        }

        let checkout = app.buttons["Check out"]
        XCTAssertTrue(checkout.waitForExistence(timeout: 10), "Check out missing")
        checkout.tap()
        sleep(2)
        shot("checkout_open")
        let place = app.buttons["Place order"]
        note("CHECKOUT place_enabled_on_open=\(place.exists && place.isEnabled)")
        note("CHECKOUT address_prefilled=\(app.staticTexts['Ships to'].exists)")
        note("CHECKOUT skip_button=\(app.buttons["Skip for now"].exists)")
        shot("checkout_scrolled_none")
        app.swipeUp()
        sleep(1)
        shot("checkout_bottom")
    }

    func testCartRemoveHasNoUndo() {
        launch()
        tab("Cart")
        let remove = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Remove '")).firstMatch
        XCTAssertTrue(remove.waitForExistence(timeout: 10))
        let before = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Remove '")).count
        remove.tap()
        sleep(1)
        shot("cart_after_remove")
        let after = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Remove '")).count
        note("CART_REMOVE rows \(before) -> \(after)")
        note("CART_REMOVE undo_affordance=\(app.buttons["Undo"].exists || app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'undo'")).count > 0)")
        note("CART_REMOVE confirm_dialog=\(app.alerts.count > 0)")
    }

    func testClosetFindAndSort() {
        launch()
        tab("Closet")
        shot("closet_top")
        size("closet_sort", app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Sort closet'")).firstMatch)
        let search = app.textFields["Search your closet"]
        XCTAssertTrue(search.waitForExistence(timeout: 10), "closet search missing")
        search.tap()
        search.typeText("a")
        sleep(1)
        shot("closet_search_a_keyboard")
        note("CLOSET keyboard_shown=\(app.keyboards.count > 0)")
        // Scroll the results: does the keyboard dismiss?
        app.swipeUp()
        sleep(1)
        shot("closet_search_scrolled")
        note("CLOSET keyboard_after_scroll=\(app.keyboards.count > 0)")
        let clear = app.buttons["Clear closet search"]
        size("closet_clear", clear)
        if clear.exists { clear.tap() }
        sleep(1)

        let sort = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Sort closet'")).firstMatch
        if sort.exists {
            sort.tap()
            sleep(1)
            shot("closet_sort_menu")
            app.buttons["Price: high to low"].tap()
            sleep(1)
            shot("closet_sorted_price_high")
        }
        // Switch tabs and come back: does the filter/sort survive?
        tab("Today"); tab("Closet")
        shot("closet_after_tab_roundtrip")
        note("CLOSET sort_label_after_roundtrip=\(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Sort closet'")).firstMatch.label)")
        note("CLOSET outfit_entry=\(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'outfit'")).count > 0 || app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'outfit'")).count > 0)")
    }

    func testForYouDeck() {
        launch()
        tab("For You")
        sleep(2)
        shot("foryou_initial")
        let pass = app.buttons["Pass"]
        let add = app.buttons["Add to cart"]
        size("foryou_pass", pass)
        size("foryou_add", add)
        let picksBefore = app.staticTexts.matching(NSPredicate(format: "label CONTAINS ' picks'")).firstMatch.label
        add.tap()
        sleep(2)
        shot("foryou_after_add")
        let picksAfter = app.staticTexts.matching(NSPredicate(format: "label CONTAINS ' picks'")).firstMatch.label
        note("FORYOU picks \(picksBefore) -> \(picksAfter)")
        note("FORYOU undo_after_add=\(app.buttons["Undo"].exists)")
        note("FORYOU cart_badge_label=\(app.buttons["Cart"].label)")
        pass.tap()
        sleep(2)
        shot("foryou_after_pass")
        note("FORYOU undo_after_pass=\(app.buttons["Undo"].exists)")
        // A real swipe on the deck.
        let card = app.otherElements.matching(NSPredicate(format: "label CONTAINS ' coins'")).firstMatch
        if card.exists {
            card.swipeRight()
            sleep(2)
            shot("foryou_after_swipe_right")
        }
    }

    func testProfileAndCoinShop() {
        launch()
        tab("You")
        shot("you_top")
        app.swipeUp()
        sleep(1)
        shot("you_scrolled")
        note("YOU privacy_link=\(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'privacy'")).count > 0 || app.links.matching(NSPredicate(format: "label CONTAINS[c] 'privacy'")).count > 0)")
        note("YOU terms_link=\(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'terms'")).count > 0 || app.links.matching(NSPredicate(format: "label CONTAINS[c] 'terms'")).count > 0)")
        note("YOU sign_out_needs_confirm_tap_count=1 (source)")
        app.swipeDown(); app.swipeDown()
        let wallet = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Coin balance'")).firstMatch
        XCTAssertTrue(wallet.waitForExistence(timeout: 5))
        wallet.tap()
        sleep(2)
        shot("coin_shop")
    }
}
