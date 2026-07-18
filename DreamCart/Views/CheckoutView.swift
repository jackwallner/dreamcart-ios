import SwiftUI

// The virtual checkout. Reached from the cart's "Check out" button. Collects a
// shipping address and shows a full itemized receipt — subtotal, virtual
// shipping (always on us), estimated tax, order total — so it reads like a real
// store checkout. The receipt dollars are imaginary; the only real cost is the
// coin total, which is what the server actually charges via purchase_cart.
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

    // Virtual receipt math. Coins -> pretend dollars; tax is a flat rate on the
    // subtotal; shipping is listed then discounted to free for the dopamine.
    private var subtotal: Double { Double(shop.cartTotal) * Format.coinToDollar }
    private var tax: Double { subtotal * 0.0875 }
    private var orderTotal: Double { subtotal + tax }

    private var addressComplete: Bool { shipping.address.isValid }
    private var canPlace: Bool { addressComplete && shop.canAfford && !placing }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    addressCard
                    summaryCard
                    receiptCard
                    Text("Virtual delivery — no real address is needed and nothing ships. Dollar amounts are imaginary; you pay only in coins.")
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
        VStack(alignment: .leading, spacing: 12) {
            cardHeader("shippingbox.fill", "Shipping address")
            if addressComplete {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ships to").font(.dcCaption).foregroundStyle(Theme.subtle(scheme))
                    Text(shipping.address.multilineSummary)
                        .font(.dcBodyText)
                        .foregroundStyle(Theme.ink(scheme))
                }
            } else {
                Text("Add a pretend address so your order has somewhere to \"go.\"")
                    .font(.dcCaption)
                    .foregroundStyle(Theme.subtle(scheme))
            }
            Button {
                Haptics.tap()
                showEditAddress = true
            } label: {
                Text(addressComplete ? "Edit address" : "Add address")
                    .font(.dcLabel)
                    .foregroundStyle(Theme.violet)
            }
        }
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
            receiptRow("Subtotal", Format.money(subtotal))
            receiptRow("Shipping", "FREE", accent: .green)
            receiptRow("Estimated tax", Format.money(tax))
            Divider()
            HStack {
                Text("Order total").font(.dcBody).foregroundStyle(Theme.ink(scheme)).lineLimit(1)
                Spacer()
                Text(Format.money(orderTotal)).font(.dcPrice).foregroundStyle(Theme.ink(scheme))
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            HStack {
                Text("You pay").font(.dcBody).foregroundStyle(Theme.ink(scheme)).lineLimit(1)
                Spacer()
                CoinLabel(amount: shop.cartTotal, size: 17).foregroundStyle(Theme.ink(scheme))
            }
            .padding(.top, 2)
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
            } else if !addressComplete {
                Text("Add a pretend address to place the order")
                    .font(.dcSub).foregroundStyle(Theme.subtle(scheme))
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
