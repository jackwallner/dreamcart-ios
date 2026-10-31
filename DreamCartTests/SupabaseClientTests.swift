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

    /// Signs in with a token already inside the client's 120 s refresh window,
    /// so the next call asks the auth server for a new one, and answers that
    /// refresh with `status` and `body`.
    private func signInThenRefreshAnswers(status: Int, body: String) async throws {
        SupabaseStub.install { request in
            guard SupabaseStub.isTokenCall(request) else { return .json("[]") }
            if SupabaseStub.grantType(request) == "refresh_token" {
                return .json(body, status: status)
            }
            return .json(SupabaseStub.tokenJSON(expiresIn: 30))
        }
        try await signIn()
    }

    private func accessTokenThrows() async -> Bool {
        do {
            _ = try await SupabaseClient.shared.accessToken()
            return false
        } catch {
            return true
        }
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

    // MARK: refresh

    /// A 503 or a 429 from the auth server, or a Wi-Fi sign-in page answering
    /// 200, is not the server refusing the refresh token. Treating it as
    /// that cleared the Keychain session and left the app signed in on screen
    /// but unable to claim, spin or check out.
    func testServerErrorOnRefreshKeepsTheSession() async throws {
        try await signInThenRefreshAnswers(status: 503, body: #"{"message":"upstream unavailable"}"#)

        let failed = await accessTokenThrows()
        let signedIn = await SupabaseClient.shared.isSignedIn

        XCTAssertTrue(failed, "A refused refresh cannot produce a token")
        XCTAssertTrue(signedIn, "A 503 from the auth server says nothing about the refresh token")
    }

    func testRateLimitedRefreshKeepsTheSession() async throws {
        try await signInThenRefreshAnswers(status: 429, body: #"{"error_code":"over_request_rate_limit"}"#)

        let failed = await accessTokenThrows()
        let signedIn = await SupabaseClient.shared.isSignedIn

        XCTAssertTrue(failed)
        XCTAssertTrue(signedIn, "A rate limit passes; the refresh token is still good")
    }

    func testUnreadableRefreshResponseKeepsTheSession() async throws {
        try await signInThenRefreshAnswers(status: 200, body: "<html>Sign in to the hotel Wi-Fi</html>")

        let failed = await accessTokenThrows()
        let signedIn = await SupabaseClient.shared.isSignedIn

        XCTAssertTrue(failed)
        XCTAssertTrue(signedIn, "A captive portal is not the auth server")
    }

    /// The other side of the rule: a refresh token the server no longer honours
    /// does end the session.
    func testRefusedRefreshTokenEndsTheSession() async throws {
        try await signInThenRefreshAnswers(
            status: 400,
            body: #"{"error":"invalid_grant","error_description":"Invalid Refresh Token: Already Used"}"#)

        let failed = await accessTokenThrows()
        let signedIn = await SupabaseClient.shared.isSignedIn

        XCTAssertTrue(failed)
        XCTAssertFalse(signedIn)
    }
}
