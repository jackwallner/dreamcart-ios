import Foundation

// The dress-up avatar. Rendering happens server-side (render-avatar edge
// function): the fit is generated once, cached in the public avatar-art
// bucket, and every later view is a plain storage fetch. The client just
// picks a look and sends the chosen piece ids.

enum AvatarLook: String, CaseIterable, Identifiable {
    case aria, maya, zoe, kai, leo, rio

    var id: String { rawValue }

    var label: String { rawValue.capitalized }
}

enum Avatar {
    struct RenderResponse: Decodable {
        let ok: Bool
        let url: String?
        let cached: Bool?
    }

    /// Ask the server for the on-model shot of this fit. Returns the hosted
    /// image URL, or nil when the generation queue is busy (caller offers a
    /// retry).
    static func render(look: AvatarLook, items: [Product]) async -> String? {
        guard !items.isEmpty else { return nil }
        let body: [String: Any] = [
            "look": look.rawValue,
            "product_ids": items.map { $0.id },
        ]
        guard let r: RenderResponse = try? await SupabaseClient.shared
            .callFunction("render-avatar", body: body), r.ok else { return nil }
        return r.url
    }
}
