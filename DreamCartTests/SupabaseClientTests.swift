import XCTest

/// `SupabaseClient` against a stubbed Supabase, through its real request code.
@MainActor
final class SupabaseClientTests: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        await SupabaseClient.shared.signOutLocal()
    }

    override func tearDown() async throws {
        SupabaseStub.uninstall()
        await SupabaseClient.shared.signOutLocal()
        try await super.tearDown()
    }

    private func signIn() async throws {
        try await SupabaseClient.shared.signInWithPassword(email: "shopper@example.com", password: "pw")
    }

    // MARK: writes

    /// "favorites?product_id=eq.x" is a table plus a filter. Appended as a path
    /// component the "?" was escaped, PostgREST looked for a table of that whole
    /// name, and un-favoriting (and deleting an outfit) always came back 404.
    func testWriteKeepsTheFilterAsAQueryNotPartOfTheTableName() async throws {
        SupabaseStub.install { request in
            SupabaseStub.isTokenCall(request) ? .json(SupabaseStub.tokenJSON()) : .json("[]")
        }
        try await signIn()

        _ = try await SupabaseClient.shared.write("favorites?product_id=eq.abc", method: "DELETE", body: nil)

        let delete = try XCTUnwrap(SupabaseStub.requests.first { $0.httpMethod == "DELETE" })
        XCTAssertEqual(delete.url?.path, "/rest/v1/favorites")
        XCTAssertEqual(delete.url?.query, "product_id=eq.abc")
    }

    func testWriteWithoutAFilterStillPostsToTheTable() async throws {
        SupabaseStub.install { request in
            SupabaseStub.isTokenCall(request) ? .json(SupabaseStub.tokenJSON()) : .json("[]")
        }
        try await signIn()

        _ = try await SupabaseClient.shared.write("favorites", method: "POST",
                                                  body: ["user_id": "user-1", "product_id": "abc"])

        let post = try XCTUnwrap(SupabaseStub.requests.first { $0.httpMethod == "POST" && $0.url?.path.hasSuffix("/favorites") == true })
        XCTAssertEqual(post.url?.path, "/rest/v1/favorites")
        XCTAssertNil(post.url?.query)
    }
}
