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

    private static let routeKey = "route"
    private static let newDropsValue = "new-drops"

    var tab: AppTab {
        switch self {
        case .newDrops: .today
        }
    }

    var url: URL {
        URL(string: "dreamcart://new-drops")!
    }

    var notificationPayload: [AnyHashable: Any] {
        [
            Self.routeKey: Self.newDropsValue,
            "url": url.absoluteString
        ]
    }

    static func parse(_ url: URL) -> AppRoute? {
        guard url.scheme?.lowercased() == "dreamcart",
              url.host?.lowercased() == Self.newDropsValue else { return nil }
        return .newDrops
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
