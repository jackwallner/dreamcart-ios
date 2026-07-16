import Foundation

enum AppTab: String, CaseIterable, Hashable, Sendable {
    case today
    case forYou
    case cart
    case closet
    case profile
}

enum AppRoute: Hashable {
    case newDrops
    case shop

    private static let routeKey = "route"
    private static let newDropsValue = "new-drops"

    var tab: AppTab {
        switch self {
        case .newDrops, .shop: .today
        }
    }

    var url: URL {
        switch self {
        case .newDrops: URL(string: "dreamcart://new-drops")!
        case .shop: URL(string: "dreamcart://shop")!
        }
    }

    var notificationPayload: [AnyHashable: Any] {
        switch self {
        case .newDrops:
            [Self.routeKey: Self.newDropsValue, "url": url.absoluteString]
        case .shop:
            ["url": url.absoluteString]
        }
    }

    static func parse(_ url: URL) -> AppRoute? {
        guard url.scheme?.lowercased() == "dreamcart" else { return nil }
        switch url.host?.lowercased() {
        case Self.newDropsValue: return .newDrops
        case "shop": return .shop
        default: return nil
        }
    }

    static func parse(notificationUserInfo: [AnyHashable: Any]) -> AppRoute? {
        if let value = notificationUserInfo[Self.routeKey] as? String,
           value.lowercased() == Self.newDropsValue {
            return .newDrops
        }
        if let value = notificationUserInfo["url"] as? String,
           let url = URL(string: value) {
            return parse(url)
        }
        return nil
    }
}
