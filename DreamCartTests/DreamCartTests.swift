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

    func testHexColorParsingDoesNotCrash() {
        _ = Color(hex: "#7C3AED")
        _ = Color(hex: "FFFFFF")
        _ = Color(hex: "")   // must not crash
    }

    // MARK: helpers

    private func makeProduct(id: String, price: Int, name: String = "Item",
                             color: String = "Black") -> ProductWithBrand {
        ProductWithBrand(id: id, brandId: "b1", name: name, category: "top", slot: "top",
                         styleTags: ["minimal"], colorName: color, price: price, rarity: "common",
                         description: "", imageUrl: "", dropDate: nil, brands: nil)
    }

    private func makeMe(coins: Int) -> MeSnapshot {
        MeSnapshot(id: "u1", displayName: "Test", coins: coins, streak: 0, bestStreak: 0,
                   isPlus: false, lifetimeSpent: 0, itemsOwned: 0, canClaimDaily: true,
                   canSpin: true, lastDailyClaim: nil, lastSpinDate: nil)
    }
}
