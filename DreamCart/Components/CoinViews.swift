import SwiftUI

// A coin glyph used everywhere prices and balances appear.
struct CoinIcon: View {
    var size: CGFloat = 16
    var body: some View {
        ZStack {
            Circle().fill(Theme.goldGradient)
            Circle().strokeBorder(.white.opacity(0.55), lineWidth: size * 0.06)
            Text("$")
                // The mark scales with its coin container, so a fixed token would drift.
                .font(.system(size: size * 0.6, weight: .black))
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(width: size, height: size)
        .shadow(color: Theme.gold.opacity(0.4), radius: size * 0.12, y: 1)
    }
}

// Price / coin amount label.
struct CoinLabel: View {
    let amount: Int
    var size: CGFloat = 15
    var weight: Font.Weight = .heavy
    var body: some View {
        HStack(spacing: size * 0.28) {
            CoinIcon(size: size)
            Text(Format.coins(amount))
                // CoinLabel is a parametric primitive whose callers set its size.
                .font(.system(size: size, weight: weight))
                .monospacedDigit()
        }
    }
}

// The top-of-screen wallet pill that animates when the balance changes.
struct WalletPill: View {
    let coins: Int
    var onTap: () -> Void
    @Environment(\.colorScheme) private var scheme
    @State private var bump = false

    var body: some View {
        Button(action: { Haptics.tap(); onTap() }) {
            HStack(spacing: 7) {
                CoinIcon(size: 20)
                Text(Format.coins(coins))
                    .font(.dcNumeral)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(coins)))
                Image(systemName: "plus.circle.fill")
                    .font(.dcIconM)
                    .foregroundStyle(Theme.violet)
            }
            .foregroundStyle(Theme.ink(scheme))
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Theme.surface(scheme), in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.gold.opacity(0.35), lineWidth: 1.5))
            .shadow(color: .black.opacity(scheme == .dark ? 0 : 0.08), radius: 8, y: 3)
            .scaleEffect(bump ? 1.08 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Coin balance: \(Format.coins(coins))")
        .onChange(of: coins) { _, _ in
            withAnimation(.spring(response: 0.28, dampingFraction: 0.5)) { bump = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                withAnimation(.spring) { bump = false }
            }
        }
    }
}
