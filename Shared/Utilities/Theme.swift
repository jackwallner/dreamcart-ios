import SwiftUI

// DreamCart's design language: dopamine-forward but clean. Bold candy gradients
// for the reward moments (claim, spin, checkout), a calm near-white canvas so
// product photography stays the hero, chunky rounded cards, and gold for coins.
enum Theme {
    // Brand candy palette
    static let violet = Color(red: 0.486, green: 0.239, blue: 0.929) // #7C3AED
    static let pink   = Color(red: 1.0,   green: 0.239, blue: 0.545) // #FF3D8B
    static let coral  = Color(red: 1.0,   green: 0.541, blue: 0.396) // #FF8A65
    static let gold   = Color(red: 0.961, green: 0.702, blue: 0.004) // #F5B301
    static let goldLite = Color(red: 1.0, green: 0.827, blue: 0.306)

    static let canvas   = Color("Canvas", bundle: nil)
    // Semantic surfaces resolved for light/dark without an asset dependency.
    static func surface(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(white: 0.11) : .white
    }
    static func bg(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.055, green: 0.055, blue: 0.071)
                        : Color(red: 0.984, green: 0.976, blue: 0.965)
    }
    static func ink(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(white: 0.96) : Color(red: 0.09, green: 0.08, blue: 0.11)
    }
    static func subtle(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(white: 0.62) : Color(red: 0.45, green: 0.44, blue: 0.48)
    }

    // The signature gradient — used on reward buttons and celebration moments.
    static let candy = LinearGradient(
        colors: [violet, pink, coral],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    static let goldGradient = LinearGradient(
        colors: [goldLite, gold],
        startPoint: .top, endPoint: .bottom)

    static let corner: CGFloat = 22
    static let cardCorner: CGFloat = 18
}

extension Color {
    /// Parse "#RRGGBB" (brand accents come from the DB as hex).
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r = Double((v >> 16) & 0xFF) / 255
        let g = Double((v >> 8) & 0xFF) / 255
        let b = Double(v & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

extension View {
    /// Chunky elevated card used across the app.
    func cardStyle(_ scheme: ColorScheme, corner: CGFloat = Theme.cardCorner) -> some View {
        self
            .background(Theme.surface(scheme), in: RoundedRectangle(cornerRadius: corner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(scheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.05))
            )
            .shadow(color: .black.opacity(scheme == .dark ? 0.0 : 0.06), radius: 14, x: 0, y: 8)
    }
}

// Rarity styling — the collectible hook.
enum Rarity: String {
    case common, rare, epic, legendary

    var label: String { rawValue.capitalized }
    var color: Color {
        switch self {
        case .common:    return Color(white: 0.6)
        case .rare:      return Color(red: 0.24, green: 0.55, blue: 0.95)
        case .epic:      return Theme.violet
        case .legendary: return Theme.gold
        }
    }
    var glow: Bool { self == .epic || self == .legendary }
    init(_ s: String) { self = Rarity(rawValue: s) ?? .common }
}
