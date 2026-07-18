import AuthenticationServices
import SwiftUI

struct WelcomeView: View {
    @Environment(AuthController.self) private var auth
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    private let slides: [(icon: String, title: String, body: String, tint: Color)] = [
        ("bag.fill.badge.plus", "Shop without the guilt",
         "Real brands, real looks, zero dollars. Fill your cart with everything you'd never actually buy.", Theme.violet),
        ("gift.fill", "Free coins every day",
         "Claim a daily drop, spin the wheel, and keep your streak alive. The more you show up, the more you get.", Theme.pink),
        ("sparkles", "Build your dream closet",
         "Own the pieces, mix brands, and style full outfits with jewelry, shades and hats. All yours.", Theme.coral),
    ]

    var body: some View {
        VStack(spacing: 0) {
            if hasCompletedOnboarding {
                authenticationView
            } else {
                TabView(selection: $page) {
                    ForEach(slides.indices, id: \.self) { i in
                        slideView(slides[i]).tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(reduceMotion ? nil : .easeInOut, value: page)
                .onAppear { Analytics.track("onboarding_step", ["step": page]) }
                .onChange(of: page) { _, new in Analytics.track("onboarding_step", ["step": new]) }

                HStack(spacing: 7) {
                    ForEach(slides.indices, id: \.self) { i in
                        Button { page = i } label: {
                            Capsule()
                                .fill(i == page ? Theme.violet : Theme.subtle(scheme).opacity(0.3))
                                .frame(width: i == page ? 22 : 12, height: 12)
                                .animation(reduceMotion ? nil : .spring, value: page)
                        }
                        .accessibilityLabel("Page \(i + 1) of \(slides.count)")
                        .accessibilityAddTraits(i == page ? .isSelected : [])
                    }
                }
                .padding(.bottom, 16)

                CandyButton(title: page == slides.count - 1 ? "Get started" : "Next",
                            systemImage: "arrow.right") {
                    if page == slides.count - 1 {
                        Analytics.track("onboarding_completed")
                        auth.justCompletedOnboarding = true
                        hasCompletedOnboarding = true
                    } else {
                        page += 1
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
            }

            if let err = auth.errorMessage {
                Text(err).font(.dcCaption).foregroundStyle(.red).padding(.bottom, 6)
            }
        }
        .overlay {
            if auth.isWorking { ProgressView().scaleEffect(1.4) }
        }
    }

    private var authenticationView: some View {
        ScrollView {
            VStack(spacing: 18) {
                ZStack {
                    Circle().fill(slides[2].tint.opacity(0.15)).frame(width: 150, height: 150)
                    Image(systemName: slides[2].icon)
                        .font(.dcIconHero)
                        .foregroundStyle(slides[2].tint)
                }
                VStack(spacing: 10) {
                    Text(slides[2].title)
                        .font(.dcHero)
                        .foregroundStyle(Theme.ink(scheme))
                        .multilineTextAlignment(.center)
                    Text(slides[2].body)
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
    }

    @ViewBuilder
    private var legalLinks: some View {
        Link("Privacy Policy", destination: URL(string: "https://jackwallner.github.io/dreamcart/privacy-policy.html")!)
        Link("Terms", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
    }

    private func slideView(_ s: (icon: String, title: String, body: String, tint: Color)) -> some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 26) {
                    Spacer(minLength: 24)
                    ZStack {
                        Circle().fill(s.tint.opacity(0.15)).frame(width: 190, height: 190)
                        Image(systemName: s.icon)
                            .font(.dcIconHero)
                            .foregroundStyle(s.tint)
                    }
                    VStack(spacing: 12) {
                        Text(s.title)
                            .font(.dcHero)
                            .foregroundStyle(Theme.ink(scheme))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(s.body)
                            .font(.dcBodyText)
                            .foregroundStyle(Theme.subtle(scheme))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 34)
                    }
                    Spacer(minLength: 24)
                }
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
        }
    }
}
