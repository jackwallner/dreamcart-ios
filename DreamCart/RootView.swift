import SwiftUI

struct RootView: View {
    @Environment(AuthController.self) private var auth
    @Environment(ShopStore.self) private var shop
    @Environment(StoreController.self) private var store
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            Theme.bg(scheme).ignoresSafeArea()
            switch auth.state {
            case .unknown:
                SplashView()
            case .signedOut:
                WelcomeView()
            case .signedIn:
                MainTabView()
            }
        }
        .onChange(of: auth.state) { _, new in
            if new == .signedIn {
                Task {
                    store.configure(userId: await SupabaseClient.shared.currentUserId)
                    await shop.refreshAll()
                    await shop.reconcilePurchases()
                }
            }
        }
    }
}

struct SplashView: View {
    @State private var pulse = false
    var body: some View {
        ZStack {
            Theme.candy.ignoresSafeArea()
            VStack(spacing: 18) {
                BagMark(size: 92)
                    .scaleEffect(pulse ? 1.06 : 0.94)
                    .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
                Text("DreamCart")
                    .font(Theme.display(36, .bold))
                    .foregroundStyle(.white)
            }
        }
        .onAppear { pulse = true }
    }
}

// The bag glyph from the icon, reusable in-app.
struct BagMark: View {
    var size: CGFloat = 64
    var tint: Color = .white
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
                .fill(tint)
                .frame(width: size, height: size)
            Circle()
                .strokeBorder(tint, lineWidth: size * 0.09)
                .frame(width: size * 0.42, height: size * 0.42)
                .offset(y: -size * 0.42)
                .mask(Rectangle().frame(width: size, height: size * 0.5).offset(y: -size * 0.42))
            Image(systemName: "sparkles")
                .font(.system(size: size * 0.34, weight: .bold))
                .foregroundStyle(Theme.pink)
        }
        .frame(width: size, height: size * 1.2)
    }
}
