import SwiftUI
import UIKit

// DreamCart's design language: dopamine-forward but clean. Bold candy gradients
// for the reward moments (claim, spin, checkout), a calm near-white canvas so
// product photography stays the hero, chunky rounded cards, and gold for coins.
enum Theme {
    // Brand candy palette
    static let violet = Color(red: 0.486, green: 0.239, blue: 0.929) // #7C3AED
    static let pink   = Color(red: 1.0,   green: 0.239, blue: 0.545) // #FF3D8B
    /// Pink behind white badge text (4.9:1; `pink` itself measured 3.3).
    static let badgePink = Color(red: 0.8, green: 0.19, blue: 0.44)
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
        scheme == .dark ? Color(white: 0.62) : Color(red: 0.38, green: 0.37, blue: 0.41)
    }

    /// Pink and coral deepened so white text holds 4.5:1 along the whole
    /// gradient (violet 5.7, pink 4.8, coral 4.7). `pink` and `coral` stay
    /// the bright accents for icons and art.
    static let candyPink  = Color(red: 0.824, green: 0.188, blue: 0.420) // #D2306B
    static let candyCoral = Color(red: 0.788, green: 0.282, blue: 0.165) // #C9482A

    // The signature gradient: used on reward buttons and celebration moments.
    // White text sits on it, so every stop is dark enough for 4.5:1.
    static let candy = LinearGradient(
        colors: [violet, candyPink, candyCoral],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    static let goldGradient = LinearGradient(
        colors: [goldLite, gold],
        startPoint: .top, endPoint: .bottom)

    static let corner: CGFloat = 22
    static let cardCorner: CGFloat = 18

    // Typography: editorial serif (New York) for display/headline moments so the
    // app reads like a fashion catalog; plain SF for everything functional.
    static func display(_ style: Font.TextStyle, _ weight: Font.Weight = .semibold) -> Font {
        .system(style, design: .serif, weight: weight)
    }

    /// New York (serif) as a UIFont — used to make navigation-bar titles match
    /// the app's editorial serif voice instead of defaulting to SF.
    static func serifUIFont(_ size: CGFloat, _ weight: UIFont.Weight,
                            relativeTo textStyle: UIFont.TextStyle) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.serif) else { return base }
        return UIFontMetrics(forTextStyle: textStyle)
            .scaledFont(for: UIFont(descriptor: descriptor, size: size))
    }

    /// Make every UINavigationBar large + inline title render in serif so the
    /// system page titles ("You", "Cart", "Shop"…) stop clashing with the serif
    /// headlines the rest of the app draws by hand. Called once at launch.
    @MainActor
    static func configureNavigationBarAppearance() {
        let ink = UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(white: 0.96, alpha: 1)
            : UIColor(red: 0.09, green: 0.08, blue: 0.11, alpha: 1) }
        let titleAttrs: [NSAttributedString.Key: Any] =
            [.font: serifUIFont(17, .bold, relativeTo: .headline), .foregroundColor: ink]
        let largeAttrs: [NSAttributedString.Key: Any] =
            [.font: serifUIFont(34, .bold, relativeTo: .largeTitle), .foregroundColor: ink]

        // Blurred bar once content scrolls under it…
        let standard = UINavigationBarAppearance()
        standard.configureWithDefaultBackground()
        standard.titleTextAttributes = titleAttrs
        standard.largeTitleTextAttributes = largeAttrs
        // …but transparent at the top so the large title floats on the canvas,
        // matching the app's seamless look.
        let edge = UINavigationBarAppearance()
        edge.configureWithTransparentBackground()
        edge.titleTextAttributes = titleAttrs
        edge.largeTitleTextAttributes = largeAttrs

        let proxy = UINavigationBar.appearance()
        proxy.standardAppearance = standard
        proxy.compactAppearance = standard
        proxy.scrollEdgeAppearance = edge
    }

    @MainActor
    static func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear

        let proxy = UITabBar.appearance()
        proxy.standardAppearance = appearance
        proxy.scrollEdgeAppearance = appearance
        proxy.isTranslucent = true
    }
}

// The DreamCart type scale. Two voices: the editorial serif layer (screen
// heroes, section titles, product names) and functional SF (buttons, rows,
// captions, numerals). Every Text in the app uses one of these tokens — never
// a raw .system size — so the whole app reads as one catalog.
extension Font {
    // Editorial serif
    static let dcHero     = Theme.display(.largeTitle, .bold) // splash, welcome, unboxing
    static let dcTitle    = Theme.display(.title, .bold)      // page titles, product name
    static let dcSection  = Theme.display(.title2, .bold)     // section headers
    static let dcCard     = Theme.display(.title3, .bold)     // card headlines
    static let dcItem     = Theme.display(.headline, .semibold) // product names on tiles/rows

    // Functional SF
    static let dcJumbo    = Font.system(.largeTitle, weight: .heavy) // reward numerals
    static let dcStat     = Font.system(.title2, weight: .heavy)     // stat numbers
    static let dcNumeral  = Font.system(.headline, weight: .heavy)   // wallet balance
    static let dcPrice    = Font.system(.subheadline, weight: .heavy) // prices, deltas
    static let dcButton   = Font.system(.headline, weight: .bold)    // CTAs
    static let dcBody     = Font.system(.body, weight: .semibold)    // rows, primary labels
    static let dcBodyText = Font.system(.body, weight: .medium)      // paragraphs
    static let dcSub      = Font.system(.subheadline, weight: .medium) // secondary text
    static let dcLabel    = Font.system(.subheadline, weight: .bold) // small action links
    static let dcCaption  = Font.system(.caption, weight: .medium)   // fine print
    static let dcOverline = Font.system(.caption, weight: .heavy)    // uppercase micro-labels
    static let dcBadge    = Font.system(.caption2, weight: .black)   // NEW / rarity chips

    // SF Symbols use a shared size scale. Weight belongs to the token so icons
    // at the same hierarchy level keep the same visual density.
    static let dcIconS    = Font.system(.subheadline, weight: .medium)
    static let dcIconM    = Font.system(.title3, weight: .semibold)
    static let dcIconL    = Font.system(.title, weight: .bold)
    static let dcIconXL   = Font.system(.largeTitle, weight: .medium)
    static let dcIconHero = Font.system(.largeTitle, weight: .semibold)
}

// User-selectable appearance. Light is the default brand look.
enum Appearance: String, CaseIterable, Identifiable {
    case light, dark, system
    var id: String { rawValue }
    var label: String {
        switch self {
        case .light: return String(localized: "Light")
        case .dark: return String(localized: "Dark")
        case .system: return String(localized: "Auto")
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
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

extension Color {
    /// A brand accent that reads as text on the page: the accent itself when it
    /// already clears 4.5:1, else blended toward the ink colour until it does.
    /// Catalog accents run from near-white to saturated, so raw use measured 1.4:1.
    static func brandText(hex: String, scheme: ColorScheme) -> Color {
        let page = scheme == .dark ? (0.055, 0.055, 0.071) : (0.984, 0.976, 0.965)
        let ink = scheme == .dark ? (0.96, 0.96, 0.96) : (0.09, 0.08, 0.11)
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let accent = (Double((v >> 16) & 0xFF) / 255, Double((v >> 8) & 0xFF) / 255, Double(v & 0xFF) / 255)
        func lum(_ c: (Double, Double, Double)) -> Double {
            func f(_ x: Double) -> Double { x <= 0.03928 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4) }
            return 0.2126 * f(c.0) + 0.7152 * f(c.1) + 0.0722 * f(c.2)
        }
        func ratio(_ a: (Double, Double, Double), _ b: (Double, Double, Double)) -> Double {
            let hi = max(lum(a), lum(b)), lo = min(lum(a), lum(b))
            return (hi + 0.05) / (lo + 0.05)
        }
        var mix = 0.0
        var c = accent
        while ratio(c, page) < 4.5, mix < 1 {
            mix += 0.1
            c = (accent.0 + (ink.0 - accent.0) * mix, accent.1 + (ink.1 - accent.1) * mix,
                 accent.2 + (ink.2 - accent.2) * mix)
        }
        return Color(red: c.0, green: c.1, blue: c.2)
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

    var label: String {
        switch self {
        case .common: return String(localized: "Common")
        case .rare: return String(localized: "Rare")
        case .epic: return String(localized: "Epic")
        case .legendary: return String(localized: "Legendary")
        }
    }
    /// The all-caps form on rarity tags, one whole key per rarity.
    var badgeLabel: String {
        switch self {
        case .common: return String(localized: "COMMON")
        case .rare: return String(localized: "RARE")
        case .epic: return String(localized: "EPIC")
        case .legendary: return String(localized: "LEGENDARY")
        }
    }
    var color: Color {
        switch self {
        case .common:    return Color(white: 0.6)
        case .rare:      return Color(red: 0.24, green: 0.55, blue: 0.95)
        case .epic:      return Theme.violet
        case .legendary: return Theme.gold
        }
    }
    /// Fill behind a white badge label: the plain colours measured 1.9 to 3.4:1.
    var badgeColor: Color {
        switch self {
        case .common:    return Color(white: 0.45)
        case .rare:      return Color(red: 0.19, green: 0.44, blue: 0.76)
        case .epic:      return Theme.violet
        case .legendary: return Color(red: 0.58, green: 0.42, blue: 0.0)
        }
    }
    /// The label colour on the dark haul summary, where `color` measured 1.9 to 2.7:1.
    var onDarkColor: Color {
        switch self {
        case .common:    return Color(white: 0.8)
        case .rare:      return Color(red: 0.55, green: 0.75, blue: 1.0)
        case .epic:      return Color(red: 0.76, green: 0.64, blue: 1.0)
        case .legendary: return Theme.goldLite
        }
    }
    var glow: Bool { self == .epic || self == .legendary }
    init(_ s: String) { self = Rarity(rawValue: s) ?? .common }
}
