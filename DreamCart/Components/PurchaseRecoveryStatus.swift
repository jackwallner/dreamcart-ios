import SwiftUI

struct PurchaseRecoveryStatus: View {
    var plus: Bool? = nil
    @Environment(ShopStore.self) private var shop

    private var visible: Bool {
        switch plus {
        case true: shop.purchaseRecovery.pendingPlus
        case false: shop.purchaseRecovery.pendingCoins != nil
        case nil: shop.purchaseRecovery.hasPending
        }
    }

    var body: some View {
        if visible {
            VStack(spacing: 8) {
                if plus != false, shop.purchaseRecovery.pendingPlus {
                    Text("Activating membership")
                }
                if plus != true, shop.purchaseRecovery.pendingCoins != nil {
                    Text("Purchase received, adding coins")
                }
                if let error = shop.purchaseRecovery.lastError {
                    Text(error).foregroundStyle(Theme.pink)
                }
                if shop.purchaseRecovery.isRecovering {
                    ProgressView()
                } else {
                    Button(plus == true ? "Retry activation" : "Retry delivery") {
                        Task { await shop.reconcilePurchases() }
                    }
                }
                Link("Support", destination: URL(string: "https://jackwallner.github.io/dreamcart/support.html")!)
            }
            .font(.dcCaption)
            .multilineTextAlignment(.center)
        }
    }
}
