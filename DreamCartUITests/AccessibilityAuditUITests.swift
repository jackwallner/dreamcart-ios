import XCTest

/// Persona audit: larger text, imperfect vision, limited one-handed reach.
///
/// Walks the guest path (onboarding, browse, product detail, sign-in gate) and
/// the DreamCart+ paywall at default and accessibility text sizes. It never
/// signs in, buys or writes anything. Every test records screenshots, element
/// frames and the system accessibility audit as attachments instead of failing
/// on findings, so the run always produces a full report.
final class AccessibilityAuditUITests: XCTestCase {

    private static let ax3 = "UICTContentSizeCategoryAccessibilityXL"
    private static let ax5 = "UICTContentSizeCategoryAccessibilityXXXL"

    override func setUp() {
        continueAfterFailure = true
    }

    // MARK: - Onboarding

    func testOnboardingAtAX5() {
        let app = launch(size: Self.ax5, completedOnboarding: false, guest: false)
        shot(app, "onb_1_ax5")
        logFrames(app, "onb_1_frames", labels: ["Next", "Page 1 of 3", "Page 2 of 3", "Page 3 of 3"])
        audit(app, "onb_1_ax5")

        let next = app.buttons["Next"]
        XCTAssertTrue(next.waitForExistence(timeout: 20), "Next button missing at AX5")
        record("Next hittable at AX5 slide 1: \(next.isHittable)")
        next.tap()
        shot(app, "onb_2_ax5")
        app.buttons["Next"].tap()
        shot(app, "onb_3_ax5")
        audit(app, "onb_3_ax5")

        let start = app.buttons["Get started"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        record("Get started hittable at AX5: \(start.isHittable) frame: \(start.frame)")
    }

    /// The sign-in screen a new user reaches after the slides. Skips the slides
    /// with a fixture: a `-hasCompletedOnboarding NO` launch argument overrides
    /// the stored value, so tapping Get started could never leave the slides.
    func testSignInAtAX5() {
        let app = launch(size: Self.ax5, completedOnboarding: true, guest: false)
        let guest = app.buttons["Browse without an account"]
        XCTAssertTrue(guest.waitForExistence(timeout: 120), "sign-in screen never appeared")
        sleep(2)
        shot(app, "signin_ax5")
        logFrames(app, "signin_ax5_frames", labels: ["Browse without an account", "Privacy Policy", "Terms", "Sign in with Apple"])
        audit(app, "signin_ax5")
        record("Browse without an account hittable without scrolling at AX5: \(guest.isHittable)")
        app.swipeUp()
        sleep(1)
        shot(app, "signin_ax5_scrolled")
    }

    func testOnboardingDefaultSize() {
        let app = launch(size: nil, completedOnboarding: false, guest: false)
        shot(app, "onb_1_default")
        logFrames(app, "onb_1_default_frames", labels: ["Next", "Page 1 of 3", "Page 2 of 3", "Page 3 of 3"])
        audit(app, "onb_1_default")
    }

    // MARK: - Guest browse

    func testGuestBrowseAtAX3() {
        let app = launch(size: Self.ax3, completedOnboarding: true, guest: true)
        XCTAssertTrue(app.buttons["Today"].waitForExistence(timeout: 150), "tab bar never appeared")
        sleep(6)
        shot(app, "today_ax3")
        logFrames(app, "tabbar_ax3_frames", labels: ["Today", "For You", "Cart", "Closet", "You", "Sign in"])
        audit(app, "today_ax3")

        // Scroll to find product cards and the brand shelves.
        app.swipeUp()
        sleep(1)
        shot(app, "today_scrolled_ax3")

        let card = app.buttons.matching(NSPredicate(format: "label CONTAINS 'coins'")).firstMatch
        if card.waitForExistence(timeout: 20) {
            record("first card label (AX3): \(card.label) frame: \(card.frame)")
            card.tap()
            sleep(3)
            shot(app, "detail_ax3")
            logFrames(app, "detail_ax3_frames", labels: ["Add to cart", "Add to favorites", "Back"])
            audit(app, "detail_ax3")
            app.swipeUp()
            shot(app, "detail_scrolled_ax3")
            let add = app.buttons["Add to cart"]
            if add.waitForExistence(timeout: 5) {
                add.tap()
                sleep(2)
                shot(app, "signin_gate_ax3")
                audit(app, "signin_gate_ax3")
            }
        } else {
            record("no product card appeared (catalog not loaded or network blocked)")
        }
    }

    func testGuestTabsAtAX3() {
        let app = launch(size: Self.ax3, completedOnboarding: true, guest: true)
        XCTAssertTrue(app.buttons["Today"].waitForExistence(timeout: 150))
        sleep(4)
        for tab in ["For You", "Cart", "Closet", "You"] {
            app.buttons[tab].tap()
            sleep(3)
            let name = tab.replacingOccurrences(of: " ", with: "").lowercased()
            shot(app, "tab_\(name)_ax3")
            audit(app, "tab_\(name)_ax3")
        }
    }

    func testGuestTabsDefaultSize() {
        let app = launch(size: nil, completedOnboarding: true, guest: true)
        XCTAssertTrue(app.buttons["Today"].waitForExistence(timeout: 150))
        sleep(6)
        shot(app, "today_default")
        logFrames(app, "tabbar_default_frames", labels: ["Today", "For You", "Cart", "Closet", "You", "Sign in"])
        audit(app, "today_default")
        for tab in ["For You", "You"] {
            app.buttons[tab].tap()
            sleep(3)
            let name = tab.replacingOccurrences(of: " ", with: "").lowercased()
            shot(app, "tab_\(name)_default")
            audit(app, "tab_\(name)_default")
        }
    }

    // MARK: - DreamCart+ paywall

    func testPlusPaywallAX5() {
        let app = XCUIApplication()
        app.launchEnvironment["DREAMCART_PLUS_SHOT"] = "1"
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", Self.ax5]
        app.launch()
        sleep(8)
        shot(app, "plus_ax5")
        logFrames(app, "plus_ax5_frames", labels: ["Not now", "Restore", "Terms", "Privacy"])
        audit(app, "plus_ax5")
        app.swipeUp()
        shot(app, "plus_ax5_scrolled")
        for label in ["Not now", "Restore", "Terms", "Privacy"] {
            let el = app.descendants(matching: .any)[label]
            record("plus AX5 \(label): exists \(el.exists) hittable \(el.exists && el.isHittable)")
        }
    }

    func testPlusPaywallAX3() {
        let app = XCUIApplication()
        app.launchEnvironment["DREAMCART_PLUS_SHOT"] = "1"
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", Self.ax3]
        app.launch()
        sleep(8)
        shot(app, "plus_ax3")
        logFrames(app, "plus_ax3_frames", labels: ["Not now", "Restore", "Terms", "Privacy"])
        audit(app, "plus_ax3")
    }

    func testPlusPaywallDefault() {
        let app = XCUIApplication()
        app.launchEnvironment["DREAMCART_PLUS_SHOT"] = "1"
        app.launch()
        sleep(8)
        shot(app, "plus_default")
        logFrames(app, "plus_default_frames", labels: ["Not now", "Restore", "Terms", "Privacy"])
        audit(app, "plus_default")
    }

    // MARK: - Helpers

    private func launch(size: String?, completedOnboarding: Bool, guest: Bool) -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.shop")
        // Launch arguments sit in the argument domain, which beats stored values,
        // so only pass a key when the test needs it forced on.
        if completedOnboarding { app.launchArguments += ["-hasCompletedOnboarding", "YES"] }
        if guest { app.launchArguments += ["-dreamcart.browsingAsGuest", "YES"] }
        if let size {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", size]
        }
        app.launch()
        record("launched with content size: \(size ?? "default")")
        return app
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func record(_ text: String) {
        let attachment = XCTAttachment(string: text)
        attachment.name = "note"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func logFrames(_ app: XCUIApplication, _ name: String, labels: [String]) {
        var lines: [String] = ["screen: \(app.frame)"]
        for label in labels {
            let matches = app.descendants(matching: .any).matching(
                NSPredicate(format: "label == %@ OR identifier == %@", label, label))
            if matches.count == 0 {
                lines.append("\(label): not found")
                continue
            }
            for i in 0..<min(matches.count, 3) {
                let el = matches.element(boundBy: i)
                lines.append("\(label)[\(i)] type=\(el.elementType.rawValue) frame=\(el.frame) hittable=\(el.isHittable)")
            }
        }
        let attachment = XCTAttachment(string: lines.joined(separator: "\n"))
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Runs the system accessibility audit and attaches what it finds without
    /// failing the test.
    private func audit(_ app: XCUIApplication, _ name: String) {
        let log = AuditLog()
        do {
            try app.performAccessibilityAudit { issue in
                log.add("\(issue.auditType.rawValue) | \(issue.compactDescription) | \(issue.element?.debugDescription.prefix(160) ?? "no element")")
                return true
            }
        } catch {
            log.add("audit error: \(error)")
        }
        var lines = log.snapshot()
        if lines.isEmpty { lines.append("no issues") }
        let attachment = XCTAttachment(string: lines.joined(separator: "\n"))
        attachment.name = "audit_\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

private final class AuditLog: @unchecked Sendable {
    private var lines: [String] = []
    func add(_ line: String) { lines.append(line) }
    func snapshot() -> [String] { lines }
}
