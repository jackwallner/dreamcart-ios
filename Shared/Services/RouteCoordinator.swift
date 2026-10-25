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
    private(set) var highlightedClosetIds: Set<String> = []

    // Floating-tab-bar visibility is DERIVED, never hand-toggled with a single
    // shared bool (which leaked across tabs and lost track under push-over-push).
    // Each tab counts how many detail screens are pushed on ITS own stack; the
    // bar hides only when the *currently selected* tab has a detail up, or a
    // full-screen celebration overlay (e.g. unboxing) is showing.
    private(set) var detailDepth: [AppTab: Int] = [:]
    private(set) var overlayCount = 0

    var isTabBarHidden: Bool {
        overlayCount > 0 || (detailDepth[selectedTab] ?? 0) > 0
    }

    /// A full-screen celebration covers the bar whatever is pushed.
    var isOverlayShowing: Bool { overlayCount > 0 }

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

    /// A detail screen appeared on `tab`'s navigation stack. Balanced by
    /// `poppedDetail(on:)` when it disappears. Counting (not a bool) survives
    /// SwiftUI's push-over-push ordering, where the incoming view's onAppear
    /// fires before the covered view's onDisappear.
    func pushedDetail(on tab: AppTab) {
        detailDepth[tab, default: 0] += 1
    }

    func poppedDetail(on tab: AppTab) {
        detailDepth[tab] = max(0, (detailDepth[tab] ?? 0) - 1)
    }

    /// A full-screen overlay (unboxing celebration) that should sit above the
    /// bar regardless of which tab is active.
    func setOverlayVisible(_ visible: Bool) {
        overlayCount = max(0, overlayCount + (visible ? 1 : -1))
    }

    func showClosetHighlighting(_ productIds: [String]) {
        highlightedClosetIds = Set(productIds)
        selectedTab = .closet
    }

    func clearClosetHighlight() {
        highlightedClosetIds.removeAll()
    }

    func clearPendingRoute() {
        pendingRoute = nil
        presentedRoute = nil
    }
}
