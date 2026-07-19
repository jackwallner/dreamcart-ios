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
    var showConfetti = true
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
            if !reduceMotion, showConfetti {
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
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
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

// MARK: - Post-checkout unboxing (multi-item, slot-machine-style dopamine)

/// Which micro-state the item currently on screen is in.
private enum CelebPhase: Equatable {
    case suspense
    case revealed
    case summary
}

/// The full post-checkout payoff. Every purchased item gets its own staged
/// reveal — brief suspense (blurred silhouette, rising anticipation ticks),
/// then a springy pop-in reveal with a coin burst and escalating haptics —
/// before a final "total haul" summary card with confetti and the biggest
/// haptic beat of the sequence. Auto-advances; tapping fast-forwards the
/// current wait, and an explicit Skip jumps straight to the summary.
///
/// No slot-machine imagery (reels, levers, symbols) — the mechanics borrow
/// only the *pacing* (anticipation, escalation, big payoff), not the look.
struct UnboxingView: View {
    let items: [Product]
    let onDone: () -> Void

    @Environment(RouteCoordinator.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var index = 0
    @State private var phase: CelebPhase = .suspense
    @State private var flashOpacity: Double = 0
    @State private var burstTick = 0
    @State private var advanceNow = false
    @State private var skipToEnd = false

    private var totalCoins: Int { items.reduce(0) { $0 + $1.price } }
    private func count(_ rarity: Rarity) -> Int { items.filter { $0.rarityKind == rarity }.count }

    var body: some View {
        ZStack {
            backdrop
            VStack(spacing: 20) {
                if phase != .summary { progressHeader }
                Spacer(minLength: 0)
                Group {
                    if phase != .summary, items.indices.contains(index) {
                        RevealCard(product: items[index], phase: phase,
                                   isFinal: index == items.count - 1, reduceMotion: reduceMotion)
                            .id(items[index].id)
                            .transition(reduceMotion ? .opacity : .asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.82)),
                                removal: .opacity.combined(with: .scale(scale: 1.06))))
                    } else if phase == .summary {
                        summaryCard
                            .transition(reduceMotion ? .opacity
                                                      : .opacity.combined(with: .scale(scale: 0.92)))
                    }
                }
                Spacer(minLength: 0)
                if phase != .summary {
                    Text("Tap to continue")
                        .font(.dcCaption)
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 30)
            flashOverlay
        }
        .contentShape(Rectangle())
        .onTapGesture { if phase != .summary { advanceNow = true } }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .task { await run() }
    }

    // MARK: layout pieces

    private var backdrop: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            LinearGradient(colors: [Theme.violet.opacity(0.72), .clear, Theme.pink.opacity(0.58)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            if phase == .revealed, !reduceMotion {
                ConfettiBurst(coinsOnly: true).id(burstTick).ignoresSafeArea().allowsHitTesting(false)
            }
            if phase == .summary, !reduceMotion {
                ConfettiBurst().ignoresSafeArea().allowsHitTesting(false)
            }
        }
    }

    private var flashOverlay: some View {
        Color.white.opacity(flashOpacity).ignoresSafeArea().allowsHitTesting(false)
    }

    private var progressHeader: some View {
        HStack {
            if items.count > 1 {
                HStack(spacing: 6) {
                    ForEach(items.indices, id: \.self) { i in
                        Capsule()
                            .fill(i <= index ? Color.white : Color.white.opacity(0.25))
                            .frame(width: i == index ? 20 : 8, height: 5)
                    }
                }
                .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: index)
            }
            Spacer()
            skipButton
        }
        .padding(.horizontal, 4)
    }

    private var skipButton: some View {
        Button {
            Haptics.tap()
            skipToEnd = true
            advanceNow = true
            Analytics.track("celebration_skipped", ["item_count": items.count, "at_index": index])
        } label: {
            Text("Skip")
                .font(.dcLabel)
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(.black.opacity(0.25), in: Capsule())
        }
        .accessibilityLabel("Skip to summary")
    }

    private var summaryCard: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.seal.fill")
                .font(.dcIconHero)
                .foregroundStyle(Theme.gold)
            Text("Total Haul")
                .font(.dcHero)
                .tracking(1)
                .foregroundStyle(.white)
            VStack(spacing: 6) {
                Text(items.count == 1 ? "1 piece delivered to your closet"
                                      : "\(items.count) pieces delivered to your closet")
                    .font(.dcBodyText)
                    .foregroundStyle(.white.opacity(0.85))
                HStack(spacing: 6) {
                    Text("You spent")
                        .font(.dcSub)
                        .foregroundStyle(.white.opacity(0.7))
                    CoinLabel(amount: totalCoins, size: 18, weight: .heavy)
                        .foregroundStyle(.white)
                }
            }
            if count(.legendary) + count(.epic) + count(.rare) > 0 {
                HStack(spacing: 10) {
                    if count(.legendary) > 0 { rarityChip(.legendary, count(.legendary)) }
                    if count(.epic) > 0 { rarityChip(.epic, count(.epic)) }
                    if count(.rare) > 0 { rarityChip(.rare, count(.rare)) }
                }
            }
            CandyButton(title: "See in closet", systemImage: "sparkles") {
                Analytics.track("celebration_completed", ["item_count": items.count, "coin_total": totalCoins])
                router.showClosetHighlighting(items.map(\.id))
                onDone()
            }
            .padding(.horizontal, 40)
            .padding(.top, 4)
        }
        .padding(28)
        .accessibilityElement(children: .combine)
    }

    private func rarityChip(_ rarity: Rarity, _ n: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(n)")
                .font(.dcStat)
                .foregroundStyle(.white)
            Text(rarity.label.uppercased())
                .font(.dcBadge)
                .tracking(0.4)
                .foregroundStyle(rarity.color)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: sequencing

    private func run() async {
        guard !items.isEmpty else { onDone(); return }
        Analytics.track("celebration_shown", ["item_count": items.count])
        for i in items.indices {
            if skipToEnd || Task.isCancelled { break }
            withAnimation(reduceMotion ? .easeInOut(duration: 0.18)
                                        : .spring(response: 0.4, dampingFraction: 0.75)) {
                index = i
                phase = .suspense
            }
            await suspensePause(for: i)
            if skipToEnd || Task.isCancelled { break }
            withAnimation(reduceMotion ? .easeInOut(duration: 0.15)
                                        : .spring(response: 0.45, dampingFraction: 0.62)) {
                phase = .revealed
            }
            fireReveal(for: i)
            _ = await interruptibleWait(holdDuration(for: i))
        }
        guard !Task.isCancelled else { return }
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2)
                                    : .spring(response: 0.5, dampingFraction: 0.7)) {
            phase = .summary
        }
        fireFinale()
    }

    private func suspensePause(for i: Int) async {
        guard !reduceMotion else { return }
        let base = max(0.24, 0.6 - Double(i) * 0.05)
        for t in 0..<3 {
            if skipToEnd { return }
            Haptics.anticipationTick(intensity: 0.3 + Double(t) * 0.2 + Double(i) * 0.03)
            if await interruptibleWait(base / 3) { return }
        }
    }

    /// How long a revealed item stays up before the sequence moves on by
    /// itself. Long on purpose: the user paces the reveal by tapping, and this
    /// only kicks in if they don't.
    private func holdDuration(for i: Int) -> Double {
        4.0
    }

    /// Waits up to `seconds`, bailing early (returning `true`) if the view is
    /// tapped or the whole sequence is being skipped to the end.
    @discardableResult
    private func interruptibleWait(_ seconds: Double) async -> Bool {
        guard seconds > 0 else { return false }
        let stepNanos: UInt64 = 40_000_000
        var elapsed: UInt64 = 0
        let totalNanos = UInt64(seconds * 1_000_000_000)
        while elapsed < totalNanos {
            if Task.isCancelled || skipToEnd { return true }
            if advanceNow { advanceNow = false; return true }
            try? await Task.sleep(nanoseconds: stepNanos)
            elapsed += stepNanos
        }
        return false
    }

    private func fireReveal(for i: Int) {
        Haptics.escalate(step: i, of: items.count)
        triggerFlash(strong: i == items.count - 1)
        burstTick += 1
    }

    private func fireFinale() {
        triggerFlash(strong: true)
        Haptics.jackpot()
    }

    private func triggerFlash(strong: Bool) {
        guard !reduceMotion else { return }
        flashOpacity = strong ? 0.6 : 0.28
        withAnimation(.easeOut(duration: strong ? 0.55 : 0.28)) { flashOpacity = 0 }
    }
}

/// A single item's suspense → reveal presentation. Re-created (via `.id`) for
/// each item so its internal pulse animation restarts cleanly per piece.
private struct RevealCard: View {
    let product: Product
    let phase: CelebPhase
    let isFinal: Bool
    let reduceMotion: Bool
    @State private var haloPulse = false

    private var revealed: Bool { phase == .revealed }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(product.rarityKind.color.opacity(revealed ? (haloPulse ? 0.5 : 0.3) : 0.12))
                    .frame(width: isFinal ? 300 : 260, height: isFinal ? 300 : 260)
                    .blur(radius: 50)
                RemoteImage(url: product.imageUrl, rarity: product.rarityKind, maxPixelSize: 1000)
                    .frame(width: 230, height: 288)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(product.rarityKind.color.opacity(revealed && product.rarityKind.glow ? 1 : 0.35),
                                      lineWidth: revealed && product.rarityKind.glow ? 4 : 1.5))
                    .shadow(color: product.rarityKind.color.opacity(revealed ? 0.55 : 0), radius: 26, y: 10)
                    .blur(radius: reduceMotion ? 0 : (revealed ? 0 : 14))
                    .scaleEffect(reduceMotion ? 1 : (revealed ? 1 : 0.72))
                if !revealed {
                    Image(systemName: "sparkles")
                        .font(.dcIconHero)
                        .foregroundStyle(.white.opacity(0.85))
                        .scaleEffect(reduceMotion ? 1 : (haloPulse ? 1.15 : 0.9))
                }
            }
            VStack(spacing: 6) {
                RarityTag(rarity: product.rarityKind)
                    .opacity(revealed ? 1 : 0)
                    .scaleEffect(revealed ? 1 : 0.6)
                Text(revealed ? product.name : "???")
                    .font(.dcTitle)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                CoinLabel(amount: product.price, size: 15)
                    .foregroundStyle(.white)
                    .opacity(revealed ? 1 : 0)
                    .offset(y: revealed ? 0 : 6)
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.5, dampingFraction: 0.62),
                   value: phase)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) { haloPulse = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(revealed
            ? "\(product.name), \(Format.coins(product.price)) coins, \(product.rarityKind.label)"
            : "Revealing next item")
    }
}
