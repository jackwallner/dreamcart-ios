import Foundation

// The dress-up avatar: owned pieces are composed into one on-model editorial
// shot rendered by the same keyless image endpoint the catalog uses. The URL is
// deterministic (seeded by look + item set) so a given fit renders once and
// then serves from cache forever.

enum AvatarLook: String, CaseIterable, Identifiable {
    case aria, maya, zoe, kai, leo, rio

    var id: String { rawValue }

    var label: String { rawValue.capitalized }

    // How the model reads to the image generator.
    var promptWords: String {
        switch self {
        case .aria: return "a young woman with long straight dark hair"
        case .maya: return "a young woman with voluminous curly brown hair"
        case .zoe:  return "a young woman with a blonde chin-length bob"
        case .kai:  return "a young man with short dark hair"
        case .leo:  return "a young man with loose curly hair"
        case .rio:  return "an androgynous person with a platinum buzz cut"
        }
    }
}

enum Avatar {
    /// FNV-1a masked to 31 bits, matching the server's seed function.
    static func fnv1a(_ text: String) -> Int {
        var h: UInt32 = 0x811c9dc5
        for b in Array(text.utf8) {
            h ^= UInt32(b)
            h = h &* 0x01000193
        }
        return Int(h & 0x7fffffff)
    }

    /// "Solstice Blush Slip Dress" → "slip dress": strip the series word and
    /// the colorway so the garment noun reads cleanly in the prompt.
    static func garmentPhrase(_ product: Product) -> String {
        var noun = product.name
        if let firstSpace = noun.firstIndex(of: " ") {
            noun = String(noun[noun.index(after: firstSpace)...])
        }
        noun = noun.replacingOccurrences(of: product.colorName, with: "")
            .trimmingCharacters(in: .whitespaces)
        if noun.isEmpty { noun = product.name }
        return "\(product.colorName.lowercased()) \(noun.lowercased())"
    }

    /// One on-model shot wearing every picked piece.
    static func imageURL(look: AvatarLook, items: [Product]) -> String? {
        guard !items.isEmpty else { return nil }
        let sorted = items.sorted { $0.slot < $1.slot }
        let outfit = sorted.map(garmentPhrase).joined(separator: ", ")
        let prompt =
            "full body fashion editorial photograph of \(look.promptWords), " +
            "wearing \(outfit), standing relaxed pose, full body visible head to toe, " +
            "centered on a seamless warm ivory studio backdrop, soft even diffused " +
            "studio lighting, sharp focus, high detail, clean catalog fashion " +
            "photography, no text, no words, no logo, no watermark"
        let seed = fnv1a(look.rawValue + sorted.map { $0.id }.joined())
        let path = prompt.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? prompt
        return "https://image.pollinations.ai/prompt/\(path)" +
            "?width=800&height=1000&nologo=true&seed=\(seed)&model=flux"
    }
}
