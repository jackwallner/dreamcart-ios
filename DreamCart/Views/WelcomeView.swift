import SwiftUI

struct WelcomeView: View {
    @Environment(AuthController.self) private var auth
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    private let slides: [(icon: String, title: String, body: String, tint: Color)] = [
        ("bag.fill.badge.plus", "Shop without the guilt",
         "Original fashion, dream looks, zero dollars. Fill your cart with everything you'd never actually buy.", Theme.violet),
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
            SignInPanel(headline: slides[2].title,
                        message: slides[2].body,
                        icon: slides[2].icon,
                        tint: slides[2].tint,
                        guestAction: { auth.continueAsGuest() })
        }
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
