import SwiftUI
import UIKit

struct SpinView: View {
    @Environment(ShopStore.self) private var shop
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Must match the server wheel in spin() — slice i pays prizes[i].
    private let prizes = [50, 100, 150, 250, 400, 600, 800, 1000]
    private let sliceColors: [Color] = [
        Theme.violet, Theme.pink, Theme.coral, Theme.gold,
        Theme.violet, Theme.pink, Theme.coral, Theme.gold,
    ]
    private let slices = 8
    private var pegSpacing: Double { 360.0 / Double(slices) } // one tick per segment boundary
    private let flingThreshold: Double = 250 // deg/sec — below this a release is just a nudge, not a real spin

    @State private var angle: Double = 0
    @State private var spinning = false
    @State private var result: SpinResult?
    @State private var showReward = false

    // Drag-to-spin / fling
    @State private var isDragging = false
    @State private var dragLastAngle: Double?
    @State private var dragLastTime: Date?
    @State private var dragVelocity: Double = 0 // deg/sec, signed
    @State private var dragTickAccum: Double = 0

    // Idle "come spin me" motion
    @State private var idleWobble: Double = 0
    @State private var shimmerT: CGFloat = -1

    // The flapper that ticks over each segment peg
    @State private var flapperKick: Double = 0

    var body: some View {
        ZStack {
            Theme.bg(scheme).ignoresSafeArea()
            VStack(spacing: 30) {
                Text("Spin to win")
                    .font(.dcTitle)
                    .foregroundStyle(Theme.ink(scheme))
                    .padding(.top, 30)

                GeometryReader { geo in
                    let diameter = min(geo.size.width - 28, geo.size.height - 28)
                    ZStack {
                        wheel(diameter: diameter)
                            .frame(width: diameter, height: diameter)
                            .rotationEffect(.degrees(displayAngle))
                            .shadow(color: .black.opacity(0.28), radius: 18, y: 12)
                        if !reduceMotion {
                            shimmerOverlay(diameter: diameter)
                        }
                        hub(diameter: diameter)
                        flapper(diameter: diameter)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Circle().size(CGSize(width: diameter, height: diameter)))
                    .gesture(dragGesture(diameter: diameter))
                }
                .frame(maxWidth: 420)
                .aspectRatio(1, contentMode: .fit)
                .padding(.horizontal, 14)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Prize wheel")
                .accessibilityValue(prizes.map { "\($0) coins" }.joined(separator: ", "))
                .onAppear { setIdleWobble(true) }

                Spacer()

                CandyButton(title: canSpin ? "Spin" : "Come back tomorrow",
                            systemImage: canSpin ? "dial.medium.fill" : "clock.fill",
                            enabled: canSpin && !spinning) {
                    Task { await doSpin() }
                }
                .padding(.horizontal, 30)

                if !canSpin {
                    Text("Resets at midnight")
                        .font(.dcSub)
                        .foregroundStyle(Theme.subtle(scheme))
                }

                Button("Close") { dismiss() }
                    .font(.dcBody)
                    .foregroundStyle(Theme.subtle(scheme))
                    .padding(.bottom, 20)
                    .disabled(spinning)
            }
        }
        .overlay {
            if showReward, let r = result, let prize = r.prize {
                let t = tier(for: prize)
                RewardOverlay(title: t == .jackpot ? "JACKPOT!" : "You won",
                              amount: prize,
                              subtitle: t == .jackpot ? "Huge. Go treat yourself."
                                                       : "Added to your wallet. Spin again tomorrow.",
                              coinsOnly: t != .jackpot,
                              showConfetti: t != .small) {
                    if reduceMotion { showReward = false } else { withAnimation { showReward = false } }
                    dismiss()
                }
            }
        }
    }

    private var canSpin: Bool { shop.me?.canSpin ?? false }

    /// The rotation actually rendered — the drag/spin angle plus a small idle
    /// wobble that's suppressed the moment the wheel is touched or spinning.
    private var displayAngle: Double {
        angle + (spinning || isDragging || reduceMotion ? 0 : idleWobble)
    }

    // MARK: - Win tiers (server decides the prize; this only decides the payoff style)

    private enum WinTier { case jackpot, big, small }

    private func tier(for prize: Int) -> WinTier {
        if prize == prizes.max() { return .jackpot }
        let median = prizes.sorted()[prizes.count / 2]
        return prize >= median ? .big : .small
    }

    // MARK: - Wheel face

    private func wheel(diameter: CGFloat) -> some View {
        let labelRadius = diameter * 0.36
        let pegRadius = diameter * 0.465
        return ZStack {
            ForEach(0..<slices, id: \.self) { i in
                WheelSlice(index: i, total: slices)
                    .fill(sliceGradient(for: i, diameter: diameter))
                WheelSlice(index: i, total: slices)
                    .stroke(.white.opacity(0.55), lineWidth: 2)
                let a = Double(i) * pegSpacing
                Text(Format.coinsShort(prizes[i]))
                    .font(.dcPrice)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                    .rotationEffect(.degrees(-a + labelAngle(for: i)))
                    .offset(x: labelRadius * sin(.pi * a / 180),
                            y: -labelRadius * cos(.pi * a / 180))
            }
            // Rim lights — decorative bulbs ringing the wheel for depth/arcade feel.
            ForEach(0..<16, id: \.self) { i in
                let a = Double(i) * 22.5 * .pi / 180
                let big = i.isMultiple(of: 2)
                Circle()
                    .fill(Theme.goldGradient)
                    .frame(width: diameter * (big ? 0.026 : 0.016))
                    .overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.3), radius: 1, y: 0.5)
                    .offset(x: pegRadius * sin(a), y: -pegRadius * cos(a))
            }
        }
        .overlay(Circle().strokeBorder(Theme.goldGradient, lineWidth: diameter * 0.026))
        .overlay(Circle().stroke(.black.opacity(0.2), lineWidth: 1).padding(diameter * 0.013))
    }

    /// A faked gloss: lighter near the hub, true brand color toward the rim.
    private func sliceGradient(for i: Int, diameter: CGFloat) -> RadialGradient {
        let color = sliceColors[i]
        return RadialGradient(colors: [color.lightened(0.22), color],
                               center: UnitPoint(x: 0.5, y: 0.5),
                               startRadius: 0, endRadius: diameter * 0.52)
    }

    private func labelAngle(for index: Int) -> Double {
        let center = Double(index) * pegSpacing
        return center > 90 && center < 270 ? 180 : 0
    }

    /// Idle light sweep across the wheel face, inviting a spin.
    private func shimmerOverlay(diameter: CGFloat) -> some View {
        LinearGradient(colors: [.clear, .white.opacity(0.32), .clear],
                       startPoint: .top, endPoint: .bottom)
            .frame(width: diameter * 0.45, height: diameter * 1.7)
            .rotationEffect(.degrees(24))
            .offset(x: shimmerT * diameter)
            .blendMode(.plusLighter)
            .mask(Circle().frame(width: diameter, height: diameter))
            .allowsHitTesting(false)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 2.8).repeatForever(autoreverses: false)) {
                    shimmerT = 1.4
                }
            }
    }

    private func hub(diameter: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Theme.surface(scheme).lightened(0.1), Theme.surface(scheme)],
                                      center: UnitPoint(x: 0.35, y: 0.3),
                                      startRadius: 0, endRadius: diameter * 0.12))
            Circle().strokeBorder(Theme.goldGradient, lineWidth: 2.5)
            Circle()
                .fill(.white.opacity(0.4))
                .frame(width: diameter * 0.06, height: diameter * 0.06)
                .blur(radius: diameter * 0.02)
                .offset(x: -diameter * 0.035, y: -diameter * 0.035)
            CoinIcon(size: diameter * 0.11)
        }
        .frame(width: diameter * 0.21, height: diameter * 0.21)
        .shadow(color: .black.opacity(0.32), radius: 5, y: 3)
    }

    /// The pointer — hinged at the top so it can kick sideways as it ticks
    /// over each segment peg while the wheel spins underneath it.
    private func flapper(diameter: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Theme.ink(scheme).opacity(0.25))
                .frame(width: diameter * 0.045, height: diameter * 0.045)
                .offset(y: -(diameter * 0.44))
            Triangle()
                .fill(LinearGradient(colors: [Theme.ink(scheme), Theme.ink(scheme).opacity(0.7)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(Triangle().stroke(Theme.gold, lineWidth: 1))
                .frame(width: diameter * 0.09, height: diameter * 0.075)
                .offset(y: -(diameter * 0.53))
                .shadow(color: .black.opacity(0.35), radius: 3, y: 2)
        }
        .rotationEffect(.degrees(flapperKick), anchor: .top)
    }

    // MARK: - Drag to spin

    private func dragGesture(diameter: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                guard !reduceMotion, canSpin, !spinning else { return }
                let center = CGPoint(x: diameter / 2, y: diameter / 2)
                let vector = CGVector(dx: value.location.x - center.x, dy: value.location.y - center.y)
                let current = atan2(vector.dy, vector.dx) * 180 / .pi
                let now = Date()
                if !isDragging { Haptics.select() }
                isDragging = true
                if let last = dragLastAngle, let lastTime = dragLastTime {
                    var delta = current - last
                    if delta > 180 { delta -= 360 }
                    if delta < -180 { delta += 360 }
                    angle += delta
                    let dt = now.timeIntervalSince(lastTime)
                    if dt > 0.0005 {
                        dragVelocity = dragVelocity * 0.7 + (delta / dt) * 0.3
                    }
                    dragTickAccum += delta
                    if abs(dragTickAccum) >= pegSpacing {
                        dragTickAccum = 0
                        Haptics.select()
                        kickFlapper(direction: delta)
                    }
                }
                dragLastAngle = current
                dragLastTime = now
            }
            .onEnded { _ in
                guard !reduceMotion, canSpin, !spinning else {
                    resetDrag()
                    return
                }
                let velocity = dragVelocity
                resetDrag()
                if abs(velocity) >= flingThreshold {
                    Task { await doSpin(flungVelocity: velocity) }
                } else {
                    setIdleWobble(true)
                }
            }
    }

    private func resetDrag() {
        isDragging = false
        dragLastAngle = nil
        dragLastTime = nil
        dragVelocity = 0
        dragTickAccum = 0
    }

    private func kickFlapper(direction: Double) {
        flapperKick = direction >= 0 ? 9 : -9
        withAnimation(.interpolatingSpring(stiffness: 420, damping: 11)) { flapperKick = 0 }
    }

    // MARK: - Idle motion

    private func setIdleWobble(_ active: Bool) {
        guard !reduceMotion else { return }
        if active {
            withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) {
                idleWobble = 3
            }
        } else {
            withAnimation(.easeOut(duration: 0.25)) { idleWobble = 0 }
        }
    }

    // MARK: - Spin

    private func doSpin(flungVelocity: Double? = nil) async {
        guard canSpin, !spinning else { return }
        spinning = true
        setIdleWobble(false)
        Haptics.rigid()
        guard let r = await shop.spin(), r.ok, let slice = r.slice else {
            spinning = false
            setIdleWobble(true)
            return
        }
        result = r
        let start = angle
        if reduceMotion {
            angle = finalAngle(forSlice: slice, from: start, direction: 1, extraSpins: 0)
        } else {
            let direction: Double = (flungVelocity ?? 0) < 0 ? -1 : 1
            let target = finalAngle(forSlice: slice, from: start, direction: direction,
                                     extraSpins: extraSpins(for: flungVelocity))
            await animateSpin(from: start, to: target)
        }
        await presentResult(r)
        spinning = false
        setIdleWobble(true)
    }

    private func extraSpins(for flungVelocity: Double?) -> Double {
        guard let v = flungVelocity else { return 5 }
        return 4 + min(3, abs(v) / 500)
    }

    /// The server already picked `slice` — this only computes the rotation
    /// that makes the wheel visually land on it, honoring wherever the wheel
    /// currently rests (it may not be a multiple of 360 after a drag) and the
    /// spin's direction.
    private func finalAngle(forSlice slice: Int, from start: Double, direction: Double, extraSpins: Double) -> Double {
        let sliceCenter = Double(slice) * pegSpacing
        let desiredMod = (360 - sliceCenter).truncatingRemainder(dividingBy: 360)
        var currentMod = start.truncatingRemainder(dividingBy: 360)
        if currentMod < 0 { currentMod += 360 }
        if direction >= 0 {
            var delta = desiredMod - currentMod
            while delta <= 0 { delta += 360 }
            return start + delta + extraSpins * 360
        } else {
            var delta = currentMod - desiredMod
            while delta <= 0 { delta += 360 }
            return start - delta - extraSpins * 360
        }
    }

    /// Drives `angle` frame-by-frame with a long ease-out tail and a decaying
    /// wobble right before the stop, firing flapper-tick haptics as each
    /// segment peg passes underneath the pointer. The loop always lands
    /// exactly on `final` — the predetermined server outcome is never at risk,
    /// only the path getting there is stylized.
    private func animateSpin(from start: Double, to final: Double) async {
        let duration = 3.6
        let totalDelta = final - start
        let referenceVelocity = max(1, abs(4 * totalDelta / duration))
        let startTime = Date()
        var lastAngle = start
        var lastTime = startTime
        var distanceSinceTick: Double = 0
        while true {
            let now = Date()
            let elapsed = now.timeIntervalSince(startTime)
            let p = min(1, elapsed / duration)
            let eased = 1 - pow(1 - p, 4)
            let current = start + totalDelta * eased + wobbleOffset(p: p)
            let frameDt = now.timeIntervalSince(lastTime)
            let delta = current - lastAngle
            if frameDt > 0.0005 {
                distanceSinceTick += abs(delta)
                if distanceSinceTick >= pegSpacing {
                    distanceSinceTick = 0
                    let velocity = abs(delta) / frameDt
                    Haptics.anticipationTick(intensity: max(0.12, min(1, velocity / referenceVelocity)))
                    kickFlapper(direction: delta)
                }
            }
            angle = current
            lastAngle = current
            lastTime = now
            if p >= 1 { break }
            try? await Task.sleep(nanoseconds: 16_000_000)
        }
        angle = final
    }

    /// A decaying oscillation confined to the very end of the spin (`p` near
    /// 1) — zero at both ends so it never disturbs the ease-out curve early on
    /// and never displaces the final landing angle.
    private func wobbleOffset(p: Double) -> Double {
        let windowStart = 0.78
        guard p > windowStart else { return 0 }
        let t = min(1, (p - windowStart) / (1 - windowStart))
        let decay = 1 - t
        return decay * sin(t * 2.6 * .pi) * 7
    }

    private func presentResult(_ r: SpinResult) async {
        guard let prize = r.prize else { return }
        switch tier(for: prize) {
        case .jackpot: Haptics.jackpot()
        case .big: Haptics.celebrate()
        case .small: Haptics.success()
        }
        if reduceMotion {
            showReward = true
        } else {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) { showReward = true }
        }
        UIAccessibility.post(notification: .announcement, argument: "You won \(prize) coins")
    }
}

private extension Color {
    /// Nudges brightness up (and saturation down slightly) to fake a glossy
    /// highlight without needing real assets — used for slice/hub gradients.
    func lightened(_ amount: CGFloat) -> Color {
        let ui = UIColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(hue: h, saturation: max(0, s - amount * 0.3), brightness: min(1, b + amount), opacity: a)
    }
}

// One pie slice of the wheel.
struct WheelSlice: Shape {
    let index: Int
    let total: Int
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let per = 360.0 / Double(total)
        let start = Angle(degrees: Double(index) * per - 90 - per / 2)
        let end = Angle(degrees: Double(index + 1) * per - 90 - per / 2)
        var p = Path()
        p.move(to: center)
        p.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
        p.closeSubpath()
        return p
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}
