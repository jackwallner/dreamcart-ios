import SwiftUI

struct LoadErrorBanner: View {
    @Environment(ShopStore.self) private var shop
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.dcIconM)
                .foregroundStyle(Theme.pink)

            VStack(alignment: .leading, spacing: 3) {
                Text("Shop missed a beat")
                    .font(.dcBody)
                    .foregroundStyle(Theme.ink(scheme))
                Text(shop.loadError ?? "Try loading everything again.")
                    .font(.dcSub)
                    .foregroundStyle(Theme.subtle(scheme))
                    .lineLimit(2)
            }

            Spacer(minLength: 4)

            Button("Retry") {
                Task { await shop.refreshAll() }
            }
            .font(.dcLabel)
            .foregroundStyle(Theme.violet)
            .disabled(shop.isLoading)

            Button {
                shop.loadError = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.dcIconS)
                    .foregroundStyle(Theme.subtle(scheme))
            }
            .accessibilityLabel("Dismiss")
        }
        .padding(14)
        .cardStyle(scheme)
    }
}
