import AuthenticationServices
import SwiftUI

/// The Sign in with Apple block, shared by the welcome screen and the sign-in
/// sheet a guest gets when they tap an account-based action.
struct SignInPanel: View {
    var headline: String
    var message: String
    var icon: String = "sparkles"
    var tint: Color = Theme.coral
    /// Shown on the welcome screen so browsing never requires an account.
    var guestAction: (() -> Void)?

    @Environment(AuthController.self) private var auth
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle().fill(tint.opacity(0.15)).frame(width: 150, height: 150)
                Image(systemName: icon)
                    .font(.dcIconHero)
                    .foregroundStyle(tint)
            }
            VStack(spacing: 10) {
                Text(headline)
                    .font(.dcHero)
                    .foregroundStyle(Theme.ink(scheme))
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.dcBodyText)
                    .foregroundStyle(Theme.subtle(scheme))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)
            VStack(spacing: 12) {
                SignInWithAppleButton(.continue) { request in
                    auth.prepareRequest(request)
                } onCompletion: { result in
                    auth.handle(result)
                }
                .signInWithAppleButtonStyle(scheme == .dark ? .white : .black)
                .frame(height: 54)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
                Text("We use Sign in with Apple to save your closet and coins. Nothing is shared.")
                    .font(.dcCaption)
                    .foregroundStyle(Theme.subtle(scheme))
                    .multilineTextAlignment(.center)

                if let guestAction {
                    Button("Browse without an account", action: guestAction)
                        .font(.dcButton)
                        .foregroundStyle(Theme.violet)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.violet.opacity(0.10), in: Capsule())
                        .fixedSize(horizontal: false, vertical: true)
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 18) { legalLinks }
                    VStack(spacing: 10) { legalLinks }
                }
                .font(.dcLabel)
                .foregroundStyle(Theme.violet)

                #if DEBUG
                Button("Continue as tester") { Task { await auth.devSignIn() } }
                    .font(.dcLabel)
                    .foregroundStyle(Theme.violet)
                    .fixedSize(horizontal: false, vertical: true)
                #endif
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 28)
        }
        .padding(.top, 36)
    }

    @ViewBuilder
    private var legalLinks: some View {
        Link("Privacy Policy", destination: URL(string: "https://jackwallner.github.io/dreamcart/privacy-policy.html")!)
        Link("Terms", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
    }
}

/// Stand-in for a tab whose whole contents belong to an account (cart,
/// closet). Browsing tabs never use this.
struct GuestGateState: View {
    let icon: String
    let title: String
    let message: String
    let feature: String

    @Environment(AuthController.self) private var auth
    @Environment(RouteCoordinator.self) private var router

    var body: some View {
        VStack(spacing: 20) {
            EmptyState(icon: icon, title: title, message: message)
            VStack(spacing: 12) {
                CandyButton(title: "Sign in", systemImage: "person.crop.circle.badge.plus") {
                    auth.requireAccount(feature)
                }
                Button("Keep browsing") { router.receive(.shop) }
                    .font(.dcButton)
                    .foregroundStyle(Theme.violet)
            }
            .padding(.horizontal, 32)
        }
        .padding(.top, 60)
    }
}

/// Sheet a guest gets when they reach for an account-based feature — cart,
/// checkout, coins, closet or favorites. Browsing never presents it.
struct SignInPromptView: View {
    @Environment(AuthController.self) private var auth
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                SignInPanel(headline: "Save your haul",
                            message: "Sign in to collect coins, fill your cart and keep everything you buy in your closet. Browsing stays free.",
                            icon: "bag.fill.badge.plus",
                            tint: Theme.violet)
                if let err = auth.errorMessage {
                    Text(err)
                        .font(.dcCaption)
                        .foregroundStyle(.red)
                        .padding(.bottom, 12)
                }
            }
            .background(Theme.bg(scheme))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Not now") { dismiss() }
                        .font(.dcLabel)
                        .foregroundStyle(Theme.violet)
                }
            }
            .overlay {
                if auth.isWorking { ProgressView().scaleEffect(1.4) }
            }
        }
    }
}
