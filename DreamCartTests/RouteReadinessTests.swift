import XCTest

/// When a link, a notification or "Shop all" may open something. The router waits
/// for a shopper who is browsing and for the catalog, and the catalog does not
/// always arrive during the launch checks: a first load that failed is recovered
/// later by Retry on the load banner or a pull to refresh.
@MainActor
final class RouteReadinessTests: XCTestCase {
    /// Launched offline, signed in, nothing loaded. "Shop all" has nothing to open
    /// yet; once Retry brings the catalog in, the route that was waiting opens.
    func testRouteTappedBeforeTheCatalogLoadedOpensWhenItArrives() {
        let router = RouteCoordinator()
        router.sync(browsing: true, catalogLoaded: false)

        router.receive(.shop)
        XCTAssertNil(router.consumePresentedRoute(), "There is no catalog to shop yet")

        router.sync(browsing: true, catalogLoaded: true)
        XCTAssertEqual(router.consumePresentedRoute(), .shop)
        XCTAssertEqual(router.selectedTab, .today)
    }

    /// The same recovery, tapped after the catalog arrived: readiness used to stay
    /// "not ready" for the whole session, so this tap was swallowed too.
    func testRouteTappedAfterTheCatalogArrivedLateOpens() {
        let router = RouteCoordinator()
        router.sync(browsing: true, catalogLoaded: false)
        router.sync(browsing: true, catalogLoaded: true)

        router.receive(.shop)

        XCTAssertEqual(router.consumePresentedRoute(), .shop)
    }

    /// A catalog alone is not enough: on the welcome screen nobody is browsing.
    func testRouteStaysShutForAShopperWhoIsNotBrowsing() {
        let router = RouteCoordinator()
        router.receive(.newDrops)

        XCTAssertNil(router.sync(browsing: false, catalogLoaded: true))
        XCTAssertFalse(router.canOpenRoutes)

        XCTAssertEqual(router.sync(browsing: true, catalogLoaded: true), .newDrops)
    }

    /// Signing out closes the door again, whatever the catalog holds.
    func testSigningOutClosesRoutes() {
        let router = RouteCoordinator()
        router.sync(browsing: true, catalogLoaded: true)
        XCTAssertTrue(router.canOpenRoutes)

        router.sync(browsing: false, catalogLoaded: true)

        XCTAssertFalse(router.canOpenRoutes)
    }
}
