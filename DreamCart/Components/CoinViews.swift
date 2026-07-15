import SwiftUI

// A coin glyph used everywhere prices and balances appear.
struct CoinIcon: View {
    @ScaledMetric(relativeTo: .body) private var scaledSize: CGFloat = 16

    init(size: CGFloat = 16) {
        _scaledSize = ScaledMetric(wrappedValue: size, relativeTo: .body)
    }

    var body: some View {
        ZStack {
            Circle().fill(Theme.goldGradient)
            Circle().strokeBorder(.white.opacity(0.55), lineWidth: scaledSize * 0.06)
            Text("$")
                .font(.system(size: scaledSize * 0.6, weight: .black))
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(width: scaledSize, height: scaledSize)
        .shadow(color: Theme.gold.opacity(0.4), radius: scaledSize * 0.12, y: 1)
        .accessibilityHidden(true)
    }
}

// Price / coin amount label.
struct CoinLabel: View {
    let amount: Int
    let size: CGFloat
    let weight: Font.Weight
    @ScaledMetric(relativeTo: .body) private var scaledSize: CGFloat = 15

    init(amount: Int, size: CGFloat = 15, weight: Font.Weight = .heavy) {
        self.amount = amount
        self.size = size
        self.weight = weight
        _scaledSize = ScaledMetric(wrappedValue: size, relativeTo: .body)
    }

    var body: some View {
        HStack(spacing: scaledSize * 0.28) {
            CoinIcon(size: size)
            Text(Format.coins(amount))
                .font(.system(size: scaledSize, weight: weight))
                .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Format.coins(amount)) coins")
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
