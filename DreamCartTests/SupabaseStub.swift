import Foundation

/// Answers requests for the Supabase host from memory, so a test can drive the
/// real request-building code in `SupabaseClient` and `ShopStore` without a
/// network. `SupabaseClient` sends everything through `URLSession.shared`,
/// which honours a globally registered protocol class. Requests to any other
/// host (product art) pass through untouched.
final class SupabaseStub: URLProtocol, @unchecked Sendable {
    struct Reply {
        var status = 200
        var body = Data("[]".utf8)
        /// Seconds to hold the answer back, so a test can act while the request is out.
        var delay: TimeInterval = 0

        static func json(_ text: String, status: Int = 200, delay: TimeInterval = 0) -> Reply {
            Reply(status: status, body: Data(text.utf8), delay: delay)
        }
    }

    typealias Handler = @Sendable (URLRequest) -> Reply

    private static let lock = NSLock()
    nonisolated(unsafe) private static var handler: Handler = { _ in Reply() }
    nonisolated(unsafe) private static var seen: [URLRequest] = []

    /// Requests served since `install`, oldest first.
    static var requests: [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return seen
    }

    static func install(_ handler: @escaping Handler) {
        lock.lock()
        self.handler = handler
        seen = []
        lock.unlock()
        URLProtocol.registerClass(SupabaseStub.self)
    }

    static func uninstall() {
        URLProtocol.unregisterClass(SupabaseStub.self)
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == Config.supabaseURL.host
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        Self.seen.append(request)
        let handler = Self.handler
        Self.lock.unlock()

        let reply = handler(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: reply.status,
                                       httpVersion: "HTTP/1.1",
                                       headerFields: ["Content-Type": "application/json"])!
        let deliver: @Sendable () -> Void = { [self] in
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: reply.body)
            client?.urlProtocolDidFinishLoading(self)
        }
        if reply.delay > 0 {
            DispatchQueue.global().asyncAfter(deadline: .now() + reply.delay, execute: deliver)
        } else {
            deliver()
        }
    }

    override func stopLoading() {}

    // MARK: canned bodies

    static func isTokenCall(_ request: URLRequest) -> Bool {
        request.url?.path.hasSuffix("/auth/v1/token") == true
    }

    static func grantType(_ request: URLRequest) -> String? {
        request.url
            .flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }?
            .queryItems?.first { $0.name == "grant_type" }?.value
    }

    /// A GoTrue session. `expiresIn` under 120 puts it inside the client's
    /// refresh window straight away.
    static func tokenJSON(expiresIn: Int = 3600) -> String {
        #"{"access_token":"access-1","refresh_token":"refresh-1","expires_in":\#(expiresIn),"user":{"id":"user-1"}}"#
    }

    static let brandJSON = ##"{"id":"b1","slug":"nova","name":"Nova","tagline":"Soft tailoring","accent_hex":"#7C3AED","bg_hex":"#F2F2F2","sort":1}"##

    static let productJSON = ##"{"id":"p1","brand_id":"b1","name":"Nova Camel Trench","category":"outerwear","slot":"outerwear","style_tags":["minimal"],"color_name":"Camel","price":900,"rarity":"rare","description":"","image_url":"","drop_date":"2026-10-30","brands":\##(brandJSON)}"##

    static let meJSON = ##"{"id":"user-1","display_name":"Shopper","coins":1234,"streak":2,"best_streak":3,"is_plus":false,"lifetime_spent":0,"items_owned":0,"can_claim_daily":true,"can_spin":true,"last_daily_claim":null,"last_spin_date":null}"##
}
