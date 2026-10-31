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
}
