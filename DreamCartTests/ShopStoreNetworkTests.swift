import XCTest

/// `ShopStore` loading and writing through a stubbed Supabase.
@MainActor
final class ShopStoreNetworkTests: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        await SupabaseClient.shared.signOutLocal()
    }

    override func tearDown() async throws {
        SupabaseStub.uninstall()
        await SupabaseClient.shared.signOutLocal()
        try await super.tearDown()
    }

    /// Un-favoriting is a DELETE on `favorites?product_id=eq.<id>`. The stub
    /// routes on the path the way PostgREST does, where an unknown table is a 404.
    func testUnfavoriteRemovesTheHeart() async throws {
        SupabaseStub.install { request in
            if SupabaseStub.isTokenCall(request) { return .json(SupabaseStub.tokenJSON()) }
            guard request.url?.path == "/rest/v1/favorites" else {
                return .json(#"{"code":"PGRST205","message":"Could not find the table in the schema cache"}"#,
                             status: 404)
            }
            return .json("[]")
        }
        try await SupabaseClient.shared.signInWithPassword(email: "shopper@example.com", password: "pw")
        let shop = ShopStore()
        shop.favoriteIds = ["abc"]

        try await shop.toggleFavorite("abc")

        XCTAssertFalse(shop.isFavorite("abc"))
        XCTAssertEqual(SupabaseStub.requests.filter { $0.httpMethod == "DELETE" }.count, 1)
    }

    /// A guest has no session. Today's pull to refresh and the load banner's
    /// Retry both call `refreshAll()`, which used to stop at `me` with "Please
    /// sign in." and never fetch the public catalog, so a guest whose first
    /// load failed could not get it back without quitting the app.
    func testRefreshAllWithoutASessionLoadsTheCatalogInsteadOfAskingToSignIn() async throws {
        SupabaseStub.install { request in
            let query = request.url?.query ?? ""
            switch request.url?.path {
            case "/rest/v1/brands":
                return .json("[\(SupabaseStub.brandJSON)]")
            case "/rest/v1/products":
                return query.contains("offset=") ? .json("[]") : .json("[\(SupabaseStub.productJSON)]")
            default:
                return .json("[]")
            }
        }
        let shop = ShopStore()

        await shop.refreshAll()

        XCTAssertNil(shop.loadError)
        XCTAssertEqual(shop.brands.map(\.id), ["b1"])
        XCTAssertEqual(shop.products.map(\.id), ["p1"])
        XCTAssertTrue(shop.hasLoadedOnce)
        await finishCatalogPaging(of: shop)
    }

    /// The guest fallback must not take over for someone who is signed in: they
    /// still get their balance and a clean load.
    func testRefreshAllWithASessionStillLoadsTheAccount() async throws {
        SupabaseStub.install { request in
            if SupabaseStub.isTokenCall(request) { return .json(SupabaseStub.tokenJSON()) }
            let query = request.url?.query ?? ""
            switch request.url?.path {
            case "/rest/v1/rpc/me":
                return .json(SupabaseStub.meJSON)
            case "/rest/v1/brands":
                return .json("[\(SupabaseStub.brandJSON)]")
            case "/rest/v1/products":
                return query.contains("offset=") ? .json("[]") : .json("[\(SupabaseStub.productJSON)]")
            default:
                return .json("[]")
            }
        }
        try await SupabaseClient.shared.signInWithPassword(email: "shopper@example.com", password: "pw")
        let shop = ShopStore()

        await shop.refreshAll()

        XCTAssertNil(shop.loadError)
        XCTAssertEqual(shop.coins, 1234)
        XCTAssertEqual(shop.products.map(\.id), ["p1"])
        let askedForTheProfile = SupabaseStub.requests.contains { $0.url?.path == "/rest/v1/rpc/me" }
        XCTAssertTrue(askedForTheProfile)
        await finishCatalogPaging(of: shop)
    }

    /// The closet is one request of the bootstrap. A failed one was swallowed:
    /// the Closet tab then said "Your closet is empty" to someone with a closet,
    /// the pieces they own showed "Add to cart", and nothing on screen said the
    /// load had failed. The load banner (with its Retry) now covers it.
    func testRefreshAllReportsAClosetThatDidNotLoad() async throws {
        SupabaseStub.install { request in
            if SupabaseStub.isTokenCall(request) { return .json(SupabaseStub.tokenJSON()) }
            let query = request.url?.query ?? ""
            switch request.url?.path {
            case "/rest/v1/rpc/me": return .json(SupabaseStub.meJSON)
            case "/rest/v1/brands": return .json("[\(SupabaseStub.brandJSON)]")
            case "/rest/v1/products":
                return query.contains("offset=") ? .json("[]") : .json("[\(SupabaseStub.productJSON)]")
            case "/rest/v1/closet_items": return .json(#"{"message":"upstream unavailable"}"#, status: 503)
            default: return .json("[]")
            }
        }
        try await SupabaseClient.shared.signInWithPassword(email: "shopper@example.com", password: "pw")
        let shop = ShopStore()

        await shop.refreshAll()

        XCTAssertNotNil(shop.loadError, "A closet that failed to load must not look like an empty one")
        XCTAssertEqual(shop.coins, 1234, "The rest of the account still loads")
        XCTAssertTrue(shop.hasLoadedOnce)
        await finishCatalogPaging(of: shop)
    }

    /// For You's "Reconsider passes" brings passed pieces back. It only emptied
    /// the set in memory: the passes stay in `recommendation_feedback`, and the
    /// next `refreshAll()` (every launch, every pull to refresh) loaded them
    /// again, so the deck emptied itself once more.
    func testReconsideringPassesRemovesThemOnTheServerToo() async throws {
        SupabaseStub.install { request in
            SupabaseStub.isTokenCall(request) ? .json(SupabaseStub.tokenJSON()) : .json("[]")
        }
        try await SupabaseClient.shared.signInWithPassword(email: "shopper@example.com", password: "pw")
        let shop = ShopStore()
        shop.dismissedRecommendationIds = ["p1", "p2"]

        shop.resetRecommendationDismissals()

        XCTAssertTrue(shop.dismissedRecommendationIds.isEmpty)
        // The delete goes out from a task of its own.
        for _ in 0..<100 where !SupabaseStub.requests.contains(where: { $0.httpMethod == "DELETE" }) {
            try? await Task.sleep(for: .milliseconds(50))
        }
        let delete = try XCTUnwrap(SupabaseStub.requests.first { $0.httpMethod == "DELETE" })
        XCTAssertEqual(delete.url?.path, "/rest/v1/recommendation_feedback")
        XCTAssertEqual(delete.url?.query, "action=eq.dismissed",
                       "Only the passes go; a piece the shopper carted stays recorded as carted")
    }

    /// An order that went through with its answer lost leaves the pieces in the
    /// cart. The retry finds them owned, and the server answers `nothing_to_buy`.
    /// The cart used to keep them, so every retry failed the same way.
    func testCheckoutOfPiecesAlreadyOwnedClearsThemFromTheCart() async throws {
        let owned = #"{"acquired_at":"2026-11-08T09:00:00Z","products":\#(SupabaseStub.productJSON)}"#
        SupabaseStub.install { request in
            if SupabaseStub.isTokenCall(request) { return .json(SupabaseStub.tokenJSON()) }
            switch request.url?.path {
            case "/rest/v1/rpc/purchase_cart":
                return .json(#"{"ok":false,"reason":"nothing_to_buy","coins":1234}"#)
            case "/rest/v1/closet_items":
                return .json("[\(owned)]")
            case "/rest/v1/rpc/me":
                return .json(SupabaseStub.meJSON)
            default:
                return .json(#"{"code":"PGRST205","message":"Could not find the table in the schema cache"}"#,
                             status: 404)
            }
        }
        try await SupabaseClient.shared.signInWithPassword(email: "shopper@example.com", password: "pw")
        let shop = ShopStore()
        shop.cartIds = ["p1"]

        let result = await shop.checkout()

        XCTAssertEqual(result?.reason, "nothing_to_buy")
        XCTAssertTrue(shop.cartIds.isEmpty)
        XCTAssertTrue(shop.ownedIds.contains("p1"))
        XCTAssertEqual(shop.coins, 1234)
    }

    /// The catalog's remaining pages load in a task of their own; let it ask
    /// for its page before the stub goes away.
    private func finishCatalogPaging(of shop: ShopStore) async {
        for _ in 0..<100 {
            let pagedAgain = SupabaseStub.requests.contains { $0.url?.query?.contains("offset=") == true }
            if pagedAgain && !shop.isLoadingMoreProducts { return }
            try? await Task.sleep(for: .milliseconds(50))
        }
    }
}
