import SwiftUI

// A burst of confetti + coins for reward moments. Purely decorative; overlaid
// above content and self-dismisses.
struct ConfettiPiece: Identifiable {
    let id = UUID()
    let x: CGFloat
    let color: Color
    let size: CGFloat
    let delay: Double
    let rotation: Double
    let isCoin: Bool
}

struct ConfettiBurst: View {
    var coinsOnly = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pieces: [ConfettiPiece] = []
    @State private var go = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let palette: [Color] = [Theme.violet, Theme.pink, Theme.coral, Theme.gold, Theme.goldLite]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { p in
                    Group {
                        if p.isCoin {
                            CoinIcon(size: p.size)
                        } else {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(p.color)
                                .frame(width: p.size, height: p.size * 1.6)
                        }
                    }
                    .rotationEffect(.degrees(reduceMotion ? p.rotation : (go ? p.rotation + 260 : p.rotation)))
                    .position(x: p.x * geo.size.width,
                              y: reduceMotion ? geo.size.height * 0.34 : (go ? geo.size.height * 1.05 : -40))
                    .opacity(reduceMotion ? 0.75 : (go ? 0 : 1))
                    .animation(reduceMotion ? nil : .easeIn(duration: 1.5).delay(p.delay), value: go)
                }
            }
            .onAppear {
                guard !reduceMotion else { return }
                pieces = (0..<44).map { i in
                    ConfettiPiece(
                        x: CGFloat.random(in: 0.05...0.95),
                        color: palette.randomElement()!,
                        size: coinsOnly ? CGFloat.random(in: 16...26) : CGFloat.random(in: 7...12),
                        delay: Double(i) * 0.012,
                        rotation: Double.random(in: 0...360),
                        isCoin: coinsOnly ? true : Bool.random())
                }
                guard !reduceMotion else { return }
                go = true
            }
        }
        .allowsHitTesting(false)
    }
}

// Full-screen reward moment: staged title, coin count, and completion action.
struct RewardOverlay: View {
    let title: String
    let amount: Int
    let subtitle: String
    var coinsOnly = true
    let onDismiss: () -> Void
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var stage = 0
    @State private var glow = false

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
                .onTapGesture { onDismiss() }
            LinearGradient(colors: [Theme.violet.opacity(0.35), .clear, Theme.pink.opacity(0.3)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            if !reduceMotion {
                ConfettiBurst(coinsOnly: coinsOnly).ignoresSafeArea()
            }
            VStack(spacing: 14) {
                Text(title)
                    .font(.dcSection)
                    .foregroundStyle(Theme.subtle(scheme))
                    .opacity(stage >= 1 ? 1 : 0)
                    .offset(y: stage >= 1 ? 0 : 8)
                ZStack {
                    Circle()
                        .fill(Theme.gold.opacity(glow ? 0.2 : 0.08))
                        .frame(width: 156, height: 156)
                        .blur(radius: 18)
                    HStack(spacing: 8) {
                        CoinIcon(size: 44)
                        Text("+\(Format.coins(amount))")
                            .font(.dcJumbo)
                            .foregroundStyle(Theme.ink(scheme))
                            .monospacedDigit()
                    }
                }
                .scaleEffect(stage >= 2 ? 1 : 0.72)
                .opacity(stage >= 2 ? 1 : 0)
                Text(subtitle)
                    .font(.dcBodyText)
                    .foregroundStyle(Theme.subtle(scheme))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .opacity(stage >= 3 ? 1 : 0)
                Button(action: onDismiss) {
                    Text("Nice")
                        .font(.dcButton)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Theme.candy, in: Capsule())
                }
                .padding(.horizontal, 60)
                .padding(.top, 8)
                .opacity(stage >= 3 ? 1 : 0)
            }
            .padding(28)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityLabel("\(title), \(Format.coins(amount)) coins. \(subtitle)")
        .onAppear {
            guard !reduceMotion else {
                stage = 3
                glow = true
                return
            }
            withAnimation(.easeOut(duration: 0.22)) { stage = 1 }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.62).delay(0.18)) { stage = 2 }
            withAnimation(.easeOut(duration: 0.3).delay(0.48)) { stage = 3 }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true).delay(0.35)) { glow = true }
        }
    }
}
