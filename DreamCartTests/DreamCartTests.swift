import SwiftUI
import XCTest
@testable import DreamCart

final class DreamCartTests: XCTestCase {

    func testCoinFormatting() {
        XCTAssertEqual(Format.coins(1000), "1,000")
        XCTAssertEqual(Format.coins(1234567), "1,234,567")
        XCTAssertEqual(Format.coinsShort(950), "950")
        XCTAssertEqual(Format.coinsShort(1000), "1k")
        XCTAssertEqual(Format.coinsShort(12400), "12k")
        XCTAssertEqual(Format.coinsShort(3200), "3.2k")
    }

    func testRarityMapping() {
        XCTAssertEqual(Rarity("legendary"), .legendary)
        XCTAssertEqual(Rarity("nonsense"), .common)
        XCTAssertTrue(Rarity.epic.glow)
        XCTAssertFalse(Rarity.common.glow)
    }

    func testCoinPackCatalogIntegrity() {
        // Ids must match the server webhook / redeem maps exactly.
        let ids = Set(CoinPack.all.map(\.productId))
        XCTAssertTrue(ids.contains("com.jackwallner.shop.coins.pocket"))
        XCTAssertTrue(ids.contains("com.jackwallner.shop.coins.vault"))
        XCTAssertEqual(CoinPack.all.count, 5)
        // Coins strictly increase with tier.
        let coins = CoinPack.all.map(\.coins)
        XCTAssertEqual(coins, coins.sorted())
    }

    @MainActor
    func testCartMathAndAffordability() {
        let shop = ShopStore()
        shop.products = [
            makeProduct(id: "a", price: 300),
            makeProduct(id: "b", price: 500),
            makeProduct(id: "c", price: 250),
        ]
        shop.me = makeMe(coins: 700)
        shop.cartIds = ["a", "b"]

        XCTAssertEqual(shop.cartTotal, 800)
        XCTAssertFalse(shop.canAfford)          // 800 > 700

        shop.cartIds = ["a", "c"]
        XCTAssertEqual(shop.cartTotal, 550)
        XCTAssertTrue(shop.canAfford)           // 550 <= 700
    }

    @MainActor
    func testCartToggleAndSearch() {
        let shop = ShopStore()
        shop.products = [
            makeProduct(id: "x", price: 100, name: "Verona Emerald Slip Dress", color: "Emerald"),
            makeProduct(id: "y", price: 100, name: "Nova Camel Trench", color: "Camel"),
        ]
        shop.toggleCart("x")
        XCTAssertTrue(shop.inCart("x"))
        shop.toggleCart("x")
        XCTAssertFalse(shop.inCart("x"))

        XCTAssertEqual(shop.search("emerald").map(\.id), ["x"])
        XCTAssertEqual(shop.search("camel").map(\.id), ["y"])
        XCTAssertTrue(shop.search("zzz").isEmpty)
    }

    @MainActor
    func testForYouExcludesOwnedCartedAndDismissedProducts() {
        let shop = ShopStore()
        shop.products = [
            makeProduct(id: "owned", price: 100),
            makeProduct(id: "cart", price: 100),
            makeProduct(id: "dismissed", price: 100),
            makeProduct(id: "eligible", price: 100),
        ]
        shop.ownedIds = ["owned"]
        shop.cartIds = ["cart"]
        shop.dismissedRecommendationIds = ["dismissed"]

        XCTAssertEqual(shop.forYouProducts.map(\.id), ["eligible"])
    }

    @MainActor
    func testRecommendationsPreferMatchingStyleAndDifferentComplementarySlot() {
        let shop = ShopStore()
        let anchor = makeProduct(id: "anchor", price: 100, styleTags: ["minimal"], slot: "top")
        shop.products = [
            anchor,
            makeProduct(id: "same-slot", price: 100, styleTags: ["minimal"], slot: "top"),
            makeProduct(id: "shoes", price: 100, styleTags: ["minimal"], slot: "footwear"),
            makeProduct(id: "random", price: 100, styleTags: ["party"], slot: "bottom"),
        ]

        XCTAssertEqual(shop.complementaryProducts(for: anchor).first?.id, "shoes")
    }

    @MainActor
    func testAddToCartIsIdempotent() {
        let shop = ShopStore()
        XCTAssertTrue(shop.addToCart("x"))
        XCTAssertFalse(shop.addToCart("x"))
        XCTAssertEqual(shop.cartIds, ["x"])
    }

    func testRouteParsing() {
        XCTAssertEqual(AppRoute.parse(URL(string: "dreamcart://new-drops")!), .newDrops)
        XCTAssertEqual(AppRoute.parse(URL(string: "dreamcart://shop")!), .shop)
        XCTAssertEqual(AppRoute.parse(notificationUserInfo: ["route": "new-drops"]), .newDrops)
        XCTAssertNil(AppRoute.parse(URL(string: "dreamcart://unknown")!))
    }

    @MainActor
    func testDeferredRouteSelectsTodayWhenReady() {
        let router = RouteCoordinator()
        router.receive(.newDrops)
        XCTAssertNil(router.consumePendingRoute())
        router.setReadiness(signedIn: true, catalogReady: true)
        XCTAssertEqual(router.consumePendingRoute(), .newDrops)
        XCTAssertEqual(router.selectedTab, .today)
        XCTAssertEqual(router.consumePresentedRoute(), .newDrops)
        XCTAssertNil(router.consumePresentedRoute())
    }

    @MainActor
    func testShopRouteOpensTodayCatalog() {
        let router = RouteCoordinator()
        router.setReadiness(signedIn: true, catalogReady: true)
        router.selectedTab = .cart
        router.receive(.shop)

        XCTAssertEqual(router.selectedTab, .today)
        XCTAssertEqual(router.consumePresentedRoute(), .shop)
    }

    @MainActor
    func testClosetHighlightSelectsClosetAndCanBeCleared() {
        let router = RouteCoordinator()
        router.selectedTab = .today

        router.showClosetHighlighting(["a", "b", "a"])

        XCTAssertEqual(router.selectedTab, .closet)
        XCTAssertEqual(router.highlightedClosetIds, ["a", "b"])

        router.clearClosetHighlight()
        XCTAssertTrue(router.highlightedClosetIds.isEmpty)
    }

    @MainActor
    func testCatalogPageDeduplicatesProducts() {
        let shop = ShopStore()
        shop.products = [makeProduct(id: "a", price: 100)]
        shop.appendCatalogPage([
            makeProduct(id: "a", price: 100),
            makeProduct(id: "b", price: 200),
            makeProduct(id: "b", price: 200),
        ])
        XCTAssertEqual(shop.products.map(\.id), ["a", "b"])
    }

    func testHexColorParsingDoesNotCrash() {
        _ = Color(hex: "#7C3AED")
        _ = Color(hex: "FFFFFF")
        _ = Color(hex: "")   // must not crash
    }

    // MARK: helpers

    private func makeProduct(id: String, price: Int, name: String = "Item",
                             color: String = "Black", styleTags: [String] = ["minimal"],
                             slot: String = "top") -> ProductWithBrand {
        ProductWithBrand(id: id, brandId: "b1", name: name, category: slot, slot: slot,
                         styleTags: styleTags, colorName: color, price: price, rarity: "common",
                         description: "", imageUrl: "", dropDate: nil, brands: nil)
    }

    private func makeMe(coins: Int) -> MeSnapshot {
        MeSnapshot(id: "u1", displayName: "Test", coins: coins, streak: 0, bestStreak: 0,
                   isPlus: false, lifetimeSpent: 0, itemsOwned: 0, canClaimDaily: true,
                   canSpin: true, lastDailyClaim: nil, lastSpinDate: nil)
    }
}
