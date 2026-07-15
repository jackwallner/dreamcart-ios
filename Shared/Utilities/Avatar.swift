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

    /// Ask the server for the on-model editorial shot of this fit. The request
    /// has a client timeout so the dressing room always remains usable while a
    /// caller offers retry or the composite fallback.
    static func render(look: AvatarLook, items: [Product]) async throws -> String {
        guard !items.isEmpty else { throw RenderError.emptyLook }
        let sortedItems = items.sorted { ($0.slot, $0.id) < ($1.slot, $1.id) }
        let response: RenderResponse
        do {
            response = try await SupabaseClient.shared.callFunction(
                "render-avatar",
                body: ["look": look.rawValue, "product_ids": sortedItems.map(\.id)]
            )
        } catch {
            throw RenderError.unavailable("Editorial rendering is unavailable right now.")
        }
        guard response.ok, let url = response.url, !url.isEmpty else {
            throw RenderError.unavailable(response.error ?? "Editorial rendering is unavailable right now.")
        }
        return url
    }
}
