import Foundation

// The dressing-room avatar. Rendering happens server-side (render-avatar edge
// function): the fit is generated once, cached in the public avatar-art bucket,
// and every later view is a plain storage fetch. The client just picks a look
// and sends the chosen piece ids.

enum AvatarLook: String, CaseIterable, Identifiable {
    case aria, maya, zoe, kai, leo, rio

    var id: String { rawValue }

    var label: String { rawValue.capitalized }
}

enum Avatar {
    struct RenderResponse: Decodable, Sendable {
        let ok: Bool
        let url: String?
        let cached: Bool?
        let error: String?
    }

    enum RenderError: LocalizedError, Sendable {
        case emptyLook
        case unavailable(String)
        case timedOut

        var errorDescription: String? {
            switch self {
            case .emptyLook: return "Choose at least one piece first."
            case .unavailable(let message): return message
            case .timedOut: return "The editorial look took too long to render."
            }
        }
    }

    /// Stable client key for one editorial look. Sorting mirrors the server's
    /// slot ordering so changing dictionary iteration order cannot reset a
    /// render or show a stale result for a different outfit.
    static func renderKey(look: AvatarLook, items: [Product]) -> String {
        let signature = items
            .sorted { ($0.slot, $0.id) < ($1.slot, $1.id) }
            .map { "\($0.slot):\($0.id)" }
            .joined(separator: "|")
        return "\(look.rawValue)#\(signature)"
    }

    /// Ask the server for the on-model editorial shot of this fit. render-avatar
    /// itself already retries patiently against Pollinations' one-in-flight
    /// keyless tier, so the client timeout is generous (uncached renders can
    /// legitimately take a couple of minutes under contention). If the server
    /// comes back busy (429/503 — Pollinations was saturated by other
    /// renders in flight, e.g. other profiles rendering at the same moment)
    /// this retries a few times with backoff before surfacing failure, so a
    /// caller offers retry or the composite fallback only once that's been
    /// given a real chance to land.
    static func render(look: AvatarLook, items: [Product]) async throws -> String {
        guard !items.isEmpty else { throw RenderError.emptyLook }
        let sortedItems = items.sorted { ($0.slot, $0.id) < ($1.slot, $1.id) }
        let itemIds = sortedItems.map(\.id)
        let busyMessage = "The dressing room is busy right now. Try again shortly."

        for attempt in 1...3 {
            let response: RenderResponse
            do {
                // Body is rebuilt each attempt (rather than reused) so each
                // send to the actor-isolated call is a fresh, last-use value
                // — [String: Any] isn't Sendable, so a shared instance sent
                // more than once trips strict-concurrency's reuse check.
                response = try await SupabaseClient.shared.callFunction(
                    "render-avatar",
                    body: ["look": look.rawValue, "product_ids": itemIds],
                    timeout: 170
                )
            } catch let SBError.http(code, _) where code == 429 || code == 503 {
                // render-avatar itself already retried patiently against
                // Pollinations before giving up with 503 — another render
                // (this profile or another) is occupying the one in-flight
                // slot. Back off and try again rather than failing outright.
                if attempt == 3 { throw RenderError.unavailable(busyMessage) }
                let delay = 6.0 * Double(attempt) + Double.random(in: 0...2)
                try await Task.sleep(for: .seconds(delay))
                continue
            } catch {
                // Network/timeout/decoding — no server-side signal that
                // retrying now would help more than the manual retry button
                // would, so fail fast.
                throw RenderError.unavailable("Editorial rendering is unavailable right now.")
            }
            guard response.ok, let url = response.url, !url.isEmpty else {
                throw RenderError.unavailable(response.error ?? "Editorial rendering is unavailable right now.")
            }
            return url
        }
        throw RenderError.unavailable(busyMessage)
    }
}
