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
                    .rotationEffect(.degrees(go ? p.rotation + 260 : p.rotation))
                    .position(x: p.x * geo.size.width,
                              y: go ? geo.size.height * 1.05 : -40)
                    .opacity(go ? 0 : 1)
                    .animation(.easeIn(duration: 1.5).delay(p.delay), value: go)
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
                go = true
            }
        }
        .allowsHitTesting(false)
    }
}

// Full-screen reward moment: big number, subtitle, confetti.
struct RewardOverlay: View {
    let title: String
    let amount: Int
    let subtitle: String
    var coinsOnly = true
    let onDismiss: () -> Void
    @Environment(\.colorScheme) private var scheme
    @State private var pop = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
                .onTapGesture { onDismiss() }
            if !reduceMotion { ConfettiBurst(coinsOnly: coinsOnly).ignoresSafeArea() }
            VStack(spacing: 14) {
                Text(title)
                    .font(.dcSection)
                    .foregroundStyle(Theme.subtle(scheme))
                HStack(spacing: 8) {
                    CoinIcon(size: 44)
                    Text("+\(Format.coins(amount))")
                        .font(.dcJumbo)
                        .foregroundStyle(Theme.ink(scheme))
                        .monospacedDigit()
                }
                .scaleEffect(pop ? 1 : 0.5)
                .opacity(pop ? 1 : 0)
                Text(subtitle)
                    .font(.dcBodyText)
                    .foregroundStyle(Theme.subtle(scheme))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
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
            }
            .padding(28)
        }
        .onAppear {
            if reduceMotion {
                pop = true
            } else {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.5).delay(0.05)) { pop = true }
            }
        }
    }
}
