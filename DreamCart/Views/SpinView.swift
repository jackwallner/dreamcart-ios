import SwiftUI

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

    @State private var angle: Double = 0
    @State private var spinning = false
    @State private var result: SpinResult?
    @State private var showReward = false

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
                            .rotationEffect(.degrees(angle))
                        Circle().fill(Theme.surface(scheme))
                            .frame(width: diameter * 0.21, height: diameter * 0.21)
                            .shadow(radius: 4)
                        CoinIcon(size: diameter * 0.11)
                        Triangle()
                            .fill(Theme.ink(scheme))
                            .frame(width: diameter * 0.09, height: diameter * 0.075)
                            .offset(y: -(diameter * 0.53))
                            .shadow(radius: 2)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: 420)
                .aspectRatio(1, contentMode: .fit)
                .padding(.horizontal, 14)

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
            }
        }
        .overlay {
            if showReward, let r = result, let prize = r.prize {
                RewardOverlay(title: prize >= 800 ? "JACKPOT!" : "You won",
                              amount: prize,
                              subtitle: prize >= 800 ? "Huge. Go treat yourself."
                                                     : "Added to your wallet. Spin again tomorrow.") {
                    if reduceMotion { showReward = false } else { withAnimation { showReward = false } }
                    dismiss()
                }
            }
        }
    }

    private var canSpin: Bool { shop.me?.canSpin ?? false }

    private func wheel(diameter: CGFloat) -> some View {
        let labelRadius = diameter * 0.36
        return ZStack {
            ForEach(0..<8, id: \.self) { i in
                WheelSlice(index: i, total: 8)
                    .fill(sliceColors[i])
                WheelSlice(index: i, total: 8)
                    .stroke(.white.opacity(0.5), lineWidth: 2)
                let angle = Double(i) * 45
                Text(Format.coinsShort(prizes[i]))
                    .font(.dcPrice)
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(-angle + labelAngle(for: i)))
                    .offset(x: labelRadius * sin(.pi * angle / 180),
                            y: -labelRadius * cos(.pi * angle / 180))
            }
        }
        .overlay(Circle().stroke(Theme.gold, lineWidth: 6))
    }

    private func labelAngle(for index: Int) -> Double {
        let center = Double(index) * 45
        return center > 90 && center < 270 ? 180 : 0
    }

    private func doSpin() async {
        guard canSpin, !spinning else { return }
        spinning = true
        Haptics.rigid()
        guard let r = await shop.spin(), r.ok, let slice = r.slice else {
            spinning = false
            return
        }
        result = r
        let sliceCenter = Double(slice) * 45.0
        let base = angle - angle.truncatingRemainder(dividingBy: 360)
        let target = base + 360.0 * (reduceMotion ? 0 : 5) - sliceCenter
        if reduceMotion {
            angle = target
        } else {
            withAnimation(.easeOut(duration: 3.2)) { angle = target }
            try? await Task.sleep(nanoseconds: 3_300_000_000)
        }
        Haptics.celebrate()
        if reduceMotion {
            showReward = true
        } else {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) { showReward = true }
        }
        spinning = false
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
