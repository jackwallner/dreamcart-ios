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
            Text("$")
                .font(.system(size: scaledSize * 0.56, weight: .black))
                .foregroundStyle(.white)
                .offset(y: -scaledSize * 0.015)
        }
        .frame(width: scaledSize, height: scaledSize)
        .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: max(1, scaledSize * 0.055)))
        .shadow(color: Theme.gold.opacity(0.28), radius: scaledSize * 0.1, y: 1)
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
        HStack(alignment: .center, spacing: scaledSize * 0.3) {
            CoinIcon(size: size)
            Text(Format.coins(amount))
                .font(.system(size: scaledSize, weight: weight))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .frame(minHeight: scaledSize * 1.35, alignment: .center)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Format.coins(amount)) coins")
    }
}

// The top-of-screen wallet pill that animates when the balance changes.
struct WalletPill: View {
    let coins: Int
    var onTap: () -> Void
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bump = false

    var body: some View {
        HStack(spacing: 7) {
            CoinIcon(size: 20)
            Text(Format.coins(coins))
                .font(.dcNumeral)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(minWidth: 40, alignment: .leading)
                .contentTransition(.numericText(value: Double(coins)))
                .animation(.snappy(duration: 0.35), value: coins)
            Image(systemName: "plus")
                .font(.system(.subheadline, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 25, height: 25)
                .background(Theme.violet, in: Circle())
        }
        .foregroundStyle(Theme.ink(scheme))
        .padding(.leading, 11)
        .padding(.trailing, 8)
        .frame(height: 40)
        .background(Theme.surface(scheme), in: Capsule())
        .overlay(Capsule().strokeBorder(.black.opacity(scheme == .dark ? 0 : 0.05), lineWidth: 1))
        .shadow(color: .black.opacity(scheme == .dark ? 0.22 : 0.08), radius: 7, y: 3)
        .scaleEffect(bump ? 1.05 : 1)
        .contentShape(Capsule())
        .onTapGesture { Haptics.tap(); onTap() }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Coin balance: \(Format.coins(coins))")
        .onChange(of: coins) { old, new in
            guard !reduceMotion, old != new else { return }
            // Drive the bump entirely through SwiftUI's animation timeline
            // (delay, not DispatchQueue) so back-to-back balance changes can't
            // race a stray asyncAfter callback and snap the scale back early.
            withAnimation(.spring(response: 0.28, dampingFraction: 0.5)) { bump = true }
            withAnimation(.spring(response: 0.28, dampingFraction: 0.5).delay(0.22)) { bump = false }
        }
    }
}
