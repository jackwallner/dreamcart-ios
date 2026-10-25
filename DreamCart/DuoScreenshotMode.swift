#if DEBUG
import Foundation
import Observation

/// Unattended iPhone Duo capture (gh-sim launch --device 'iPhone Duo').
/// DEBUG only, so none of it ships.
///
/// `-DuoSeed` signs a believable shopper in on this device only: the real
/// public catalog, a wallet, a cart and a closet. No Supabase session, no
/// RevenueCat, and analytics stay on the device. `-DuoTour` then walks
/// `-DuoRoutes a,b` on a timer, because `simctl openurl` raises a confirmation
/// sheet and the capture job cannot tap. `-DuoTourFirst <s>` is the delay
/// before the first route and `-DuoTourStep <s>` the dwell per route;
/// `-DuoTourFirstRegular` and `-DuoTourStepRegular` override them while split
/// (the inner display, which gh-sim starts shooting and recording a few
/// seconds after the relaunch, and whose screenshots are slower). gh-sim relaunches the app after unfolding, so the
/// folded and unfolded displays each get the whole walk.
///
/// Routes: today, product, foryou, closet, profile, shop, cart, checkout,
/// spin, coins.
enum DuoScreenshotMode {
    private static let arguments = ProcessInfo.processInfo.arguments

    static var isSeeded: Bool { arguments.contains("-DuoSeed") }
    static var wantsTour: Bool { arguments.contains("-DuoTour") }

    static func value(_ key: String) -> String? {
        guard let i = arguments.firstIndex(of: key), i + 1 < arguments.count else { return nil }
        return arguments[i + 1]
    }

    /// Picked from the catalog for how they photograph; any that have left the
    /// catalog fall back to the newest pieces.
    private static let cartPicks = [
        "43401268-c580-4cd8-9891-dfa01f9b799d", // Après Forest Oversized Blazer
        "233bda45-b3b5-4fdd-b129-484de604bb4d", // Echo Peach Loafers
        "ce213b49-b49f-4c9d-8a7a-cb7fc4a7d0d4", // Cascade Ruby Strappy Heels
    ]
    /// The piece the `product` route opens and adds to the cart.
    private static let detailPick = "3d66b12c-5b80-4fc5-8d5f-2f2512a8c0c8" // Halo Seafoam Wool Overcoat

    @MainActor
    static func seed(auth: AuthController, shop: ShopStore, shipping: ShippingAddressStore) async {
        await shop.refreshCatalogForGuest()
        let products = shop.products
        let ids = Set(products.map(\.id))

        let cart = cartPicks.filter(ids.contains)
        var cartIds = cart.count == cartPicks.count ? cart : Array(products.prefix(cartPicks.count).map(\.id))
        // A fourth piece fills the Duo's Cart pane rather than leaving a gap
        // above the total.
        if let extra = products.first(where: { !cartIds.contains($0.id) && $0.id != detailPick }) {
            cartIds.append(extra.id)
        }
        shop.cartIds = cartIds

        // A closet of earlier drops, newest first, a day or two apart.
        let reserved = Set(shop.cartIds).union([detailPick])
        let owned = products.dropFirst(24).filter { !reserved.contains($0.id) }.prefix(12)
        shop.closet = owned.map { ShopStore.plain($0) }
        shop.ownedIds = Set(owned.map(\.id))
        let formatter = ISO8601DateFormatter()
        shop.closetAcquiredAt = Dictionary(uniqueKeysWithValues: owned.enumerated().map { index, product in
            (product.id, formatter.string(from: Date().addingTimeInterval(-Double(index) * 40_000)))
        })
        shop.favoriteIds = Set(products.dropFirst(6).prefix(3).map(\.id))

        shop.me = MeSnapshot(
            id: "duo-shopper", displayName: "Maya", coins: 18_450, streak: 12, bestStreak: 21,
            isPlus: true, lifetimeSpent: 9_870, itemsOwned: owned.count,
            canClaimDaily: false, canSpin: true,
            lastDailyClaim: ShopStore.todayUTC(), lastSpinDate: nil
        )
        if shipping.address.isEmpty {
            shipping.address = ShippingAddress(name: "Maya Reyes", line1: "18 Linden Lane",
                                               city: "Brooklyn", state: "NY", zip: "11201")
        }
        auth.state = .signedIn
    }

    @MainActor
    static func runTour(router: RouteCoordinator, shop: ShopStore, isSplit: @MainActor () -> Bool) async {
        guard wantsTour else { return }
        // Give the first layout a moment, so the split reflects the display.
        try? await Task.sleep(for: .seconds(0.5))
        let split = isSplit()
        let firstKey = split ? "-DuoTourFirstRegular" : "-DuoTourFirst"
        let first = Double(value(firstKey) ?? value("-DuoTourFirst") ?? "") ?? 2
        try? await Task.sleep(for: .seconds(first))
        let stepKey = split ? "-DuoTourStepRegular" : "-DuoTourStep"
        let step = Double(value(stepKey) ?? value("-DuoTourStep") ?? "") ?? 10
        let routes = (value("-DuoRoutes") ?? "today,product,foryou,closet,profile,shop,checkout,spin")
            .split(separator: ",").map(String.init)
        let tour = DuoTour.shared

        for (index, route) in routes.enumerated() {
            if tour.reset() { try? await Task.sleep(for: .seconds(0.8)) }
            router.selectedTab = .today
            NSLog("DUOTOUR step %ld %@ split=%ld", index + 1, route, split ? 1 : 0)
            var dwell = step
            switch route {
            case "product":
                guard let product = shop.products.first(where: { $0.id == detailPick })
                    ?? shop.products.first(where: { !shop.inCart($0.id) }) else { break }
                tour.product = product
                // Adding it shows the Cart pane fill while the detail stays up.
                // It takes the oldest piece's place, so the pane holds four rows.
                try? await Task.sleep(for: .seconds(min(3, step / 3)))
                if let oldest = shop.cartIds.first { shop.removeFromCart(oldest) }
                shop.addToCart(product.id)
                dwell -= min(3, step / 3)
            case "foryou": router.selectedTab = .forYou
            case "closet": router.selectedTab = .closet
            case "profile": router.selectedTab = .profile
            case "cart": router.selectedTab = .cart
            case "shop": tour.showShop = true
            case "checkout":
                // Unfolded, the Cart is already open in its own pane.
                if !split { router.selectedTab = .cart }
                tour.checkout = true
            case "spin": tour.spin = true
            case "coins": tour.coins = true
            default: break
            }
            try? await Task.sleep(for: .seconds(dwell))
        }
        NSLog("DUOTOUR done")
    }
}

/// What the tour asks the screens to open. Each screen mirrors its flag into
/// its own presentation state.
@MainActor @Observable
final class DuoTour {
    static let shared = DuoTour()
    var product: ProductWithBrand?
    var showShop = false
    var checkout = false
    var spin = false
    var coins = false

    /// Closes everything; true when something was open.
    func reset() -> Bool {
        let wasOpen = product != nil || showShop || checkout || spin || coins
        product = nil
        showShop = false
        checkout = false
        spin = false
        coins = false
        return wasOpen
    }
}
#endif
