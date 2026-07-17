import Foundation

/// Local persistence for the fake-checkout shipping address. There's no
/// `profiles` column for this (it's pure flavor, never used to ship anything
/// real — see ShippingAddress), so it lives in UserDefaults as JSON rather
/// than round-tripping through Supabase.
@MainActor
@Observable
final class ShippingAddressStore {
    private static let key = "dreamcart.shippingAddress"
    private let defaults: UserDefaults

    var address: ShippingAddress {
        didSet { persist() }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode(ShippingAddress.self, from: data) {
            address = decoded
        } else {
            address = Self.migrateLegacyAppStorage(defaults)
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(address) else { return }
        defaults.set(data, forKey: Self.key)
    }

    /// Checkout used to keep the address as five loose @AppStorage strings.
    /// Fold any pre-existing value into the new struct once, on first read,
    /// so testers who'd already filled in an address don't lose it.
    private static func migrateLegacyAppStorage(_ defaults: UserDefaults) -> ShippingAddress {
        let legacyKeys = ["shipName", "shipStreet", "shipCity", "shipState", "shipZip"]
        guard legacyKeys.contains(where: { defaults.string(forKey: $0) != nil }) else {
            return ShippingAddress()
        }
        var address = ShippingAddress()
        address.name = defaults.string(forKey: "shipName") ?? ""
        address.line1 = defaults.string(forKey: "shipStreet") ?? ""
        address.city = defaults.string(forKey: "shipCity") ?? ""
        address.state = defaults.string(forKey: "shipState") ?? ""
        address.zip = defaults.string(forKey: "shipZip") ?? ""
        return address
    }
}
