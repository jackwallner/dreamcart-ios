import XCTest

/// What `ShopStore` keeps once the shopper it was loaded for is gone. Signing
/// out, deleting the account and a session the server ended all leave the store
/// alive for the next sign-in or guest visit, so it has to let go of the last
/// account's balance, closet and cart itself.
@MainActor
final class AccountStateTests: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        await SupabaseClient.shared.signOutLocal()
    }

    override func tearDown() async throws {
        SupabaseStub.uninstall()
        await SupabaseClient.shared.signOutLocal()
        try await super.tearDown()
    }

    private func product(_ id: String) -> ProductWithBrand {
        ProductWithBrand(id: id, brandId: "b1", name: "Item", category: "top", slot: "top",
                         styleTags: ["minimal"], colorName: "Black", price: 100, rarity: "common",
                         description: "", imageUrl: "", dropDate: nil, brands: nil)
    }

    private func shopHoldingAnAccount() -> ShopStore {
        let shop = ShopStore()
        shop.products = [product("p1"), product("p2")]
        shop.me = MeSnapshot(id: "user-1", displayName: "Shopper", coins: 4200, streak: 3, bestStreak: 5,
                             isPlus: false, lifetimeSpent: 0, itemsOwned: 1, canClaimDaily: false,
                             canSpin: false, lastDailyClaim: nil, lastSpinDate: nil)
        shop.cartIds = ["p1"]
        shop.ownedIds = ["p2"]
        shop.favoriteIds = ["p2"]
        shop.dismissedRecommendationIds = ["p3"]
        shop.acceptedRecommendationIds = ["p4"]
        shop.hasLoadedOnce = true
        return shop
    }

    /// Sign-out, then browsing as a guest: the Cart tab kept the last account's
    /// count as a badge over a screen that says the cart needs an account, and
    /// the For You deck kept hiding what that account had passed.
    func testGuestCatalogLoadDropsTheLastAccountsCartAndPasses() async throws {
        SupabaseStub.install { request in
            switch request.url?.path {
            case "/rest/v1/brands": return .json("[\(SupabaseStub.brandJSON)]")
            case "/rest/v1/products":
                return request.url?.query?.contains("offset=") == true ? .json("[]") : .json("[\(SupabaseStub.productJSON)]")
            default: return .json("[]")
            }
        }
        let shop = shopHoldingAnAccount()

        await shop.refreshCatalogForGuest()

        XCTAssertTrue(shop.cartIds.isEmpty, "A guest has no cart, so the last account's must not show on the tab bar")
        XCTAssertTrue(shop.dismissedRecommendationIds.isEmpty)
        XCTAssertTrue(shop.acceptedRecommendationIds.isEmpty)
        XCTAssertNil(shop.me)
        XCTAssertTrue(shop.ownedIds.isEmpty)
        XCTAssertEqual(shop.products.map(\.id), ["p1"], "The public catalog is the guest's to see")
        for _ in 0..<100 where shop.isLoadingMoreProducts || !SupabaseStub.requests.contains(where: { $0.url?.query?.contains("offset=") == true }) {
            try? await Task.sleep(for: .milliseconds(50))
        }
    }

    /// Signing in as someone else used to show the last account's balance and
    /// closet until the first load landed, and carry its cart into the new
    /// account's order. The splash comes back too, so nothing is drawn from
    /// the old account while the new one loads.
    func testForgetAccountLetsGoOfEverythingTheLastShopperOwned() {
        let shop = shopHoldingAnAccount()

        shop.forgetAccount()

        XCTAssertNil(shop.me)
        XCTAssertEqual(shop.coins, 0)
        XCTAssertTrue(shop.cartIds.isEmpty)
        XCTAssertTrue(shop.ownedIds.isEmpty)
        XCTAssertTrue(shop.favoriteIds.isEmpty)
        XCTAssertTrue(shop.closet.isEmpty)
        XCTAssertTrue(shop.dismissedRecommendationIds.isEmpty)
        XCTAssertTrue(shop.acceptedRecommendationIds.isEmpty)
        XCTAssertFalse(shop.hasLoadedOnce, "The next load is a first load for whoever signs in")
    }

    /// The catalog is public, not part of any account.
    func testForgetAccountKeepsTheCatalog() {
        let shop = shopHoldingAnAccount()

        shop.forgetAccount()

        XCTAssertEqual(shop.products.map(\.id), ["p1", "p2"])
    }
}
