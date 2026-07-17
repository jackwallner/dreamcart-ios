import Foundation

// Minimal Supabase data client over URLSession — no SPM dependency. Handles the
// native Sign in with Apple id_token exchange, session persistence + refresh,
// and authenticated REST / RPC / Edge Function calls. Mirrors the lightweight
// pattern Sideline uses, extended with GoTrue auth.

struct SBSession: Codable, Sendable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
    var userId: String
}

enum SBError: LocalizedError {
    case http(Int, String)
    case notAuthenticated
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .http(let code, let body): return "Server error \(code): \(body)"
        case .notAuthenticated: return "Please sign in."
        case .decoding(let m): return "Unexpected response: \(m)"
        }
    }
}

actor SupabaseClient {
    static let shared = SupabaseClient()

    private var session: SBSession?
    private let apikey = Config.supabasePublishableKey

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()
    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()

    // MARK: session lifecycle

    func restore() {
        guard let data = Keychain.load() else { return }
        session = try? JSONDecoder().decode(SBSession.self, from: data)
    }

    var isSignedIn: Bool { session != nil }
    var currentUserId: String? { session?.userId }

    private func persist() {
        guard let session, let data = try? JSONEncoder().encode(session) else { return }
        Keychain.save(data)
    }

    func signOutLocal() {
        session = nil
        Keychain.clear()
    }

    // MARK: Sign in with Apple (native id_token flow)

    /// Exchange an Apple identity token for a Supabase session. `nonce` is the
    /// RAW nonce (Supabase hashes it to match the token's claim).
    func signInWithApple(idToken: String, nonce: String, fullName: String?) async throws {
        var comps = URLComponents(url: Config.authURL.appendingPathComponent("token"),
                                  resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "grant_type", value: "id_token")]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "POST"
        req.setValue(apikey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        var body: [String: Any] = ["provider": "apple", "id_token": idToken, "nonce": nonce]
        if let fullName, !fullName.isEmpty { body["data"] = ["full_name": fullName] }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        try Self.ensureOK(resp, data)
        try storeSession(from: data)
    }

    #if DEBUG
    /// Email/password sign-in used only by the DEBUG tester button, so the full
    /// authenticated app can be driven in a headless simulator where Sign in
    /// with Apple can't complete. Never surfaced in Release.
    func signInWithPassword(email: String, password: String) async throws {
        var comps = URLComponents(url: Config.authURL.appendingPathComponent("token"),
                                  resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "grant_type", value: "password")]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "POST"
        req.setValue(apikey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["email": email, "password": password])
        let (data, resp) = try await URLSession.shared.data(for: req)
        try Self.ensureOK(resp, data)
        try storeSession(from: data)
    }
    #endif

    private func storeSession(from data: Data) throws {
        struct TokenResponse: Decodable {
            let accessToken: String
            let refreshToken: String
            let expiresIn: Int
            let user: User
            struct User: Decodable { let id: String }
        }
        let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase
        let t = try d.decode(TokenResponse.self, from: data)
        session = SBSession(accessToken: t.accessToken, refreshToken: t.refreshToken,
                            expiresAt: Date().addingTimeInterval(TimeInterval(t.expiresIn)),
                            userId: t.user.id)
        persist()
    }

    private func refreshIfNeeded() async throws {
        guard var s = session else { throw SBError.notAuthenticated }
        guard s.expiresAt.timeIntervalSinceNow < 120 else { return }
        var comps = URLComponents(url: Config.authURL.appendingPathComponent("token"),
                                  resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "grant_type", value: "refresh_token")]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "POST"
        req.setValue(apikey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["refresh_token": s.refreshToken])
        let (data, resp) = try await URLSession.shared.data(for: req)
        do {
            try Self.ensureOK(resp, data)
            try storeSession(from: data)
        } catch {
            // Refresh token dead — force re-auth.
            signOutLocal()
            throw SBError.notAuthenticated
        }
        _ = s
    }

    func accessToken() async throws -> String {
        try await refreshIfNeeded()
        guard let s = session else { throw SBError.notAuthenticated }
        return s.accessToken
    }

    // MARK: REST

    /// GET rows from a table/view with a raw PostgREST query string
    /// (e.g. "products?select=*,brands(*)&order=drop_date.desc").
    func select<T: Decodable>(_ path: String, authed: Bool = true) async throws -> T {
        let url = URL(string: Config.restURL.absoluteString + "/" + path)!
        var req = URLRequest(url: url)
        req.setValue(apikey, forHTTPHeaderField: "apikey")
        if authed, let token = try? await accessToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            req.setValue("Bearer \(apikey)", forHTTPHeaderField: "Authorization")
        }
        let (data, resp) = try await URLSession.shared.data(for: req)
        try Self.ensureOK(resp, data)
        do { return try Self.decoder.decode(T.self, from: data) }
        catch { throw SBError.decoding("\(error)") }
    }

    /// Call a Postgres RPC and decode the JSON result.
    @discardableResult
    func rpc<T: Decodable>(_ fn: String, args: [String: Any] = [:], authed: Bool = true) async throws -> T {
        var req = URLRequest(url: Config.restURL.appendingPathComponent("rpc/\(fn)"))
        req.httpMethod = "POST"
        req.setValue(apikey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        if authed {
            let token = try await accessToken()
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            req.setValue("Bearer \(apikey)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: args)
        let (data, resp) = try await URLSession.shared.data(for: req)
        try Self.ensureOK(resp, data)
        do { return try Self.decoder.decode(T.self, from: data) }
        catch { throw SBError.decoding("\(error)") }
    }

    /// Insert/delete helpers for user-owned tables (favorites, outfits).
    func write(_ path: String, method: String, body: Any?) async throws -> Data {
        var req = URLRequest(url: Config.restURL.appendingPathComponent(path))
        req.httpMethod = method
        req.setValue(apikey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue("return=representation", forHTTPHeaderField: "Prefer")
        let token = try await accessToken()
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body { req.httpBody = try JSONSerialization.data(withJSONObject: body) }
        let (data, resp) = try await URLSession.shared.data(for: req)
        try Self.ensureOK(resp, data)
        return data
    }

    // MARK: Edge functions

    // `timeout` defaults to URLSession's own request timeout (60s); pass a
    // longer value for functions that may sit behind a slow, patiently-
    // retrying upstream (e.g. render-avatar's own Pollinations backoff loop)
    // so the client doesn't time out a call the server is still on track to
    // finish and cache.
    @discardableResult
    func callFunction<T: Decodable>(_ name: String, body: [String: Any] = [:], timeout: TimeInterval? = nil) async throws -> T {
        var req = URLRequest(url: Config.functionsURL.appendingPathComponent(name))
        req.httpMethod = "POST"
        req.setValue(apikey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        if let timeout { req.timeoutInterval = timeout }
        let token = try await accessToken()
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        try Self.ensureOK(resp, data)
        do { return try Self.decoder.decode(T.self, from: data) }
        catch { throw SBError.decoding("\(error)") }
    }

    // MARK: helpers

    private static func ensureOK(_ resp: URLResponse, _ data: Data) throws {
        guard let http = resp as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw SBError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
    }
}
