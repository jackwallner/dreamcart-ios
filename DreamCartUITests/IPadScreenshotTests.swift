import XCTest

/// iPad layout proof: every main surface in all four orientations' two shapes
/// (portrait, landscape). Run with
/// `gh-sim test --scheme DreamCartUITests --only DreamCartUITests/IPadScreenshotTests --device "<iPad>"`
/// and read the PNG attachments from the results folder.
@MainActor
final class IPadScreenshotTests: XCTestCase {
    private let routes = ["today", "foryou", "closet", "profile", "cart", "product", "shop", "checkout", "spin", "coins"]

    override func setUp() { continueAfterFailure = true }

    func testPortrait() { capture(.portrait, tag: "p") }
    func testLandscape() { capture(.landscapeLeft, tag: "l") }

    private func capture(_ orientation: UIDeviceOrientation, tag: String) {
        XCUIDevice.shared.orientation = orientation
        for route in routes {
            let app = XCUIApplication(bundleIdentifier: "com.jackwallner.shop")
            app.launchArguments = ["-DuoSeed", "-DuoTour", "-DuoRoutes", route, "-DuoTourFirst", "2", "-DuoTourStep", "90"]
            app.launch()
            XCTAssertTrue(app.buttons["Closet"].firstMatch.waitForExistence(timeout: 60), route)
            sleep(route == "product" || route == "shop" ? 9 : 7)
            attach(app, "\(tag)-\(route)")
            app.terminate()
        }
        // Onboarding: the welcome pages, sign in, then the DreamCart+ offer.
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.shop")
        app.launchArguments = ["-FreshInstall"]
        app.launch()
        for (i, label) in ["Next", "Next", "Get started"].enumerated() {
            XCTAssertTrue(app.buttons[label].firstMatch.waitForExistence(timeout: 60), label)
            sleep(2)
            attach(app, "\(tag)-welcome\(i + 1)")
            app.buttons[label].firstMatch.tap()
        }
        sleep(2)
        attach(app, "\(tag)-signin")
        app.terminate()
    }

    func testPaywall() {
        for (orientation, tag) in [(UIDeviceOrientation.portrait, "p"), (.landscapeLeft, "l")] {
            XCUIDevice.shared.orientation = orientation
            let app = XCUIApplication(bundleIdentifier: "com.jackwallner.shop")
            app.launchEnvironment["DREAMCART_PLUS_SHOT"] = "1"
            app.launch()
            _ = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "per week")).firstMatch
                .waitForExistence(timeout: 25)
            sleep(2)
            attach(app, "\(tag)-plus-paywall")
            app.terminate()
        }
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
