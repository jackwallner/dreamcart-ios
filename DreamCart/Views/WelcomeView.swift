import AuthenticationServices
import SwiftUI

struct WelcomeView: View {
    @Environment(AuthController.self) private var auth
    @Environment(\.colorScheme) private var scheme
    @State private var page = 0

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
            TabView(selection: $page) {
                ForEach(slides.indices, id: \.self) { i in
                    slideView(slides[i]).tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: page)

            HStack(spacing: 7) {
                ForEach(slides.indices, id: \.self) { i in
                    Capsule()
                        .fill(i == page ? Theme.violet : Theme.subtle(scheme).opacity(0.3))
                        .frame(width: i == page ? 22 : 7, height: 7)
                        .animation(.spring, value: page)
                }
            }
            .padding(.bottom, 22)

            VStack(spacing: 12) {
                SignInWithAppleButton(.continue) { req in
                    auth.prepareRequest(req)
                } onCompletion: { result in
                    auth.handle(result)
                }
                .signInWithAppleButtonStyle(scheme == .dark ? .white : .black)
                .frame(height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Text("We use Sign in with Apple to save your closet and coins. Nothing is shared.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.subtle(scheme))
                    .multilineTextAlignment(.center)

                #if DEBUG
                Button("Continue as tester") { Task { await auth.devSignIn() } }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.violet)
                #endif
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 20)

            if let err = auth.errorMessage {
                Text(err).font(.caption).foregroundStyle(.red).padding(.bottom, 6)
            }
        }
        .overlay {
            if auth.isWorking { ProgressView().scaleEffect(1.4) }
        }
    }

    private func slideView(_ s: (icon: String, title: String, body: String, tint: Color)) -> some View {
        VStack(spacing: 26) {
            Spacer()
            ZStack {
                Circle().fill(s.tint.opacity(0.15)).frame(width: 190, height: 190)
                Image(systemName: s.icon)
                    .font(.system(size: 78, weight: .semibold))
                    .foregroundStyle(s.tint)
            }
            VStack(spacing: 12) {
                Text(s.title)
                    .font(Theme.display(29, .bold))
                    .foregroundStyle(Theme.ink(scheme))
                    .multilineTextAlignment(.center)
                Text(s.body)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.subtle(scheme))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 34)
            }
            Spacer()
        }
    }
}
