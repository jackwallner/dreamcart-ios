import SwiftUI

// The virtual checkout. Reached from the cart's "Check out" button. Shows an
// itemized coins-only receipt — subtotal, virtual shipping (always on us),
// order total — that reads like a real store checkout without ever mixing in
// dollar amounts. The optional pretend shipping address is pure flavor; the
// coin total is what the server actually charges via purchase_cart.
struct CheckoutView: View {
    /// Called after a successful order with the pieces that were bought, so the
    /// cart can run its unboxing celebration.
    let onPlaced: ([Product]) -> Void

    @Environment(ShopStore.self) private var shop
    @Environment(ShippingAddressStore.self) private var shipping
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    @State private var placing = false
    @State private var errorMessage: String?
    @State private var showEditAddress = false
    @State private var showUpsell = false
    @State private var skippedAddress = false

    private var addressComplete: Bool { shipping.address.isValid }
    // The shopper must make a shipping choice — enter a pretend address OR
    // explicitly skip it — before the order can be placed.
    private var addressResolved: Bool { addressComplete || skippedAddress }
    private var canPlace: Bool { shop.canAfford && addressResolved && !placing }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    addressCard
                    summaryCard
                    receiptCard
                    Text("Virtual delivery: no real address is needed and nothing ships. You pay only in coins.")
                        .font(.dcCaption)
                        .foregroundStyle(Theme.subtle(scheme))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
                .padding(16)
                Color.clear.frame(height: 100)
            }
            .background(Theme.bg(scheme))
            .navigationTitle("Checkout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) { placeBar }
        }
        .sheet(isPresented: $showEditAddress) { ShippingAddressView() }
        .sheet(isPresented: $showUpsell) { CoinUpsellView(trigger: .insufficientCoins) }
        .alert("Order didn't go through", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: address

    private var addressCard: some View {
        VStack(spacing: 12) {
            cardHeader("shippingbox.fill", "Shipping address")
            if addressComplete {
                VStack(spacing: 2) {
                    Text("Ships to").font(.dcCaption).foregroundStyle(Theme.subtle(scheme))
                    Text(shipping.address.multilineSummary)
                        .font(.dcBodyText)
                        .foregroundStyle(Theme.ink(scheme))
                        .multilineTextAlignment(.center)
                }
            } else if skippedAddress {
                Text("No address — your haul lands straight in your closet.")
                    .font(.dcCaption)
                    .foregroundStyle(Theme.subtle(scheme))
                    .multilineTextAlignment(.center)
            } else {
                Text("Add a pretend address so your order has somewhere to \"go,\" or skip it.")
                    .font(.dcCaption)
                    .foregroundStyle(Theme.subtle(scheme))
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 18) {
                Button {
                    Haptics.tap()
                    showEditAddress = true
                } label: {
                    Text(addressComplete ? "Edit address" : "Add address")
                        .font(.dcLabel)
                        .foregroundStyle(Theme.violet)
                }
                if !addressComplete && !skippedAddress {
                    Button {
                        Haptics.tap()
                        skippedAddress = true
                        Analytics.track("shipping_address_skipped")
                    } label: {
                        Text("Skip for now")
                            .font(.dcLabel)
                            .foregroundStyle(Theme.subtle(scheme))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
        .padding(16)
        .cardStyle(scheme)
    }

    // MARK: item summary

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            cardHeader("bag.fill", "\(shop.cartProducts.count) item\(shop.cartProducts.count == 1 ? "" : "s")")
            ForEach(shop.cartProducts) { p in
                HStack(spacing: 10) {
                    RemoteImage(url: p.imageUrl, rarity: p.rarityKind)
                        .frame(width: 40, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    Text(p.name)
                        .font(.dcItem)
                        .foregroundStyle(Theme.ink(scheme))
                        .lineLimit(2, reservesSpace: true)
                    Spacer()
                    CoinLabel(amount: p.price, size: 13).foregroundStyle(Theme.ink(scheme))
                }
            }
        }
        .padding(16)
        .cardStyle(scheme)
    }

    // MARK: receipt

    private var receiptCard: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Subtotal").font(.dcBodyText).foregroundStyle(Theme.subtle(scheme)).lineLimit(1)
                Spacer()
                CoinLabel(amount: shop.cartTotal, size: 13).foregroundStyle(Theme.ink(scheme))
            }
            receiptRow("Shipping", "FREE", accent: .green)
            Divider()
            HStack {
                Text("Order total").font(.dcBody).foregroundStyle(Theme.ink(scheme)).lineLimit(1)
                Spacer()
                CoinLabel(amount: shop.cartTotal, size: 17, weight: .heavy)
                    .foregroundStyle(Theme.ink(scheme))
            }
        }
        .padding(16)
        .cardStyle(scheme)
    }

    private func receiptRow(_ label: String, _ value: String, accent: Color? = nil) -> some View {
        HStack {
            Text(label).font(.dcBodyText).foregroundStyle(Theme.subtle(scheme)).lineLimit(1)
            Spacer()
            Text(value).font(.dcSub).foregroundStyle(accent ?? Theme.ink(scheme))
                .lineLimit(1).minimumScaleFactor(0.7)
        }
    }

    // MARK: place order

    private var placeBar: some View {
        VStack(spacing: 8) {
            if !shop.canAfford {
                Text("You need \(Format.coins(shop.cartTotal - shop.coins)) more coins")
                    .font(.dcLabel).foregroundStyle(Theme.pink)
                Button("Get more coins") { showUpsell = true }
                    .font(.dcLabel)
                    .foregroundStyle(Theme.violet)
            } else if !addressResolved {
                Text("Add a shipping address or tap “Skip for now” to continue")
                    .font(.dcLabel).foregroundStyle(Theme.subtle(scheme))
                    .multilineTextAlignment(.center)
            }
            CandyButton(title: placing ? "Placing order…" : "Place order",
                        systemImage: "checkmark.seal.fill", enabled: canPlace) {
                Task { await place() }
            }
        }
        .padding(16)
        .background(.bar)
    }

    private func place() async {
        placing = true
        defer { placing = false }
        let bought = shop.cartProducts
        guard let r = await shop.checkout() else {
            Haptics.warning()
            errorMessage = "Couldn't place your order. Try again."
            return
        }
        if r.ok {
            Haptics.celebrate()
            onPlaced(bought)
        } else {
            Haptics.warning()
            errorMessage = failureMessage(for: r.reason)
        }
    }

    private func failureMessage(for reason: String?) -> String {
        switch reason {
        case "insufficient_coins": return "You don't have enough coins for this order."
        case "nothing_to_buy": return "Your cart looks empty. Add something first."
        default: return "Couldn't place your order. Try again."
        }
    }

    private func cardHeader(_ icon: String, _ title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.dcIconS).foregroundStyle(Theme.violet)
            Text(title).font(.dcCard).foregroundStyle(Theme.ink(scheme))
        }
    }
}
