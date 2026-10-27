#if DEBUG
import Foundation

/// The release journeys' shopper (`ReleaseJourneysUITests`). DEBUG only, so
/// none of it ships.
///
/// `-QAShopper` signs in the Duo capture's seeded shopper (real public
/// catalog, a wallet, a closet, no Supabase session) with an empty cart, and
/// checkout settles on the device (`ShopStore.settleLocally`). The wallet and
/// closet are saved after every order and restored on the next launch, so a
/// journey can prove an order survives a relaunch the way the server keeps
/// it. `-QAShopperReset` drops the saved shopper first.
enum QAShopper {
    private static let arguments = ProcessInfo.processInfo.arguments
    private static let key = "dreamcart.qaShopper"

    static var isActive: Bool { arguments.contains("-QAShopper") }

    private struct Saved: Codable {
        let me: MeSnapshot
        let closet: [Product]
        let closetAcquiredAt: [String: String]
    }

    @MainActor
    static func start(auth: AuthController, shop: ShopStore, shipping: ShippingAddressStore) async {
        if arguments.contains("-QAShopperReset") { UserDefaults.standard.removeObject(forKey: key) }
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode(Saved.self, from: data) {
            await shop.refreshCatalogForGuest()
            shop.me = saved.me
            shop.closet = saved.closet
            shop.closetAcquiredAt = saved.closetAcquiredAt
            shop.ownedIds = Set(saved.closet.map(\.id))
            auth.state = .signedIn
        } else {
            await DuoScreenshotMode.seed(auth: auth, shop: shop, shipping: shipping)
            shop.cartIds = []
            save(shop)
        }
        shop.settlesLocally = true
        shop.onLocalSettle = { save(shop) }
    }

    @MainActor
    private static func save(_ shop: ShopStore) {
        guard let me = shop.me else { return }
        let saved = Saved(me: me, closet: shop.closet, closetAcquiredAt: shop.closetAcquiredAt)
        UserDefaults.standard.set(try? JSONEncoder().encode(saved), forKey: key)
    }
}
#endif
