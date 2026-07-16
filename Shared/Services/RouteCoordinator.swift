import Foundation
import Observation

@MainActor
@Observable
final class RouteCoordinator {
    var selectedTab: AppTab = .today
    private(set) var pendingRoute: AppRoute?
    private(set) var presentedRoute: AppRoute?
    private(set) var isSignedIn = false
    private(set) var isCatalogReady = false

    var canOpenRoutes: Bool { isSignedIn && isCatalogReady }

    func setReadiness(signedIn: Bool, catalogReady: Bool) {
        isSignedIn = signedIn
        isCatalogReady = catalogReady
    }

    func receive(_ route: AppRoute) {
        pendingRoute = route
        _ = consumePendingRoute()
    }

    func receive(url: URL) {
        guard let route = AppRoute.parse(url) else { return }
        receive(route)
    }

    func receive(notificationUserInfo: [AnyHashable: Any]) {
        guard let route = AppRoute.parse(notificationUserInfo: notificationUserInfo) else { return }
        receive(route)
    }

    func consumePendingRoute() -> AppRoute? {
        guard canOpenRoutes, let route = pendingRoute else { return nil }
        selectedTab = route.tab
        pendingRoute = nil
        presentedRoute = route
        return route
    }

    func consumePresentedRoute() -> AppRoute? {
        defer { presentedRoute = nil }
        return presentedRoute
    }

    func clearPendingRoute() {
        pendingRoute = nil
        presentedRoute = nil
    }
}
