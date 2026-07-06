import SwiftUI

struct SpinView: View {
    @Environment(ShopStore.self) private var shop
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

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
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(Theme.ink(scheme))
                    .padding(.top, 30)

                ZStack {
                    wheel
                        .frame(width: 300, height: 300)
                        .rotationEffect(.degrees(angle))
                    // hub
                    Circle().fill(Theme.surface(scheme))
                        .frame(width: 64, height: 64)
                        .shadow(radius: 4)
                    CoinIcon(size: 34)
                    // pointer
                    Triangle()
                        .fill(Theme.ink(scheme))
                        .frame(width: 26, height: 22)
                        .offset(y: -158)
                        .shadow(radius: 2)
                }

                Spacer()

                CandyButton(title: canSpin ? "Spin" : "Come back tomorrow",
                            systemImage: canSpin ? "dial.medium.fill" : "clock.fill",
                            enabled: canSpin && !spinning) {
                    Task { await doSpin() }
                }
                .padding(.horizontal, 30)

                Button("Close") { dismiss() }
                    .font(.system(size: 15, weight: .semibold))
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
                    withAnimation { showReward = false }
                    dismiss()
                }
            }
        }
    }

    private var canSpin: Bool { shop.me?.canSpin ?? false }

    private var wheel: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                WheelSlice(index: i, total: 8)
                    .fill(sliceColors[i])
                WheelSlice(index: i, total: 8)
                    .stroke(.white.opacity(0.5), lineWidth: 2)
                // prize label, seated in the middle of slice i (i*45° from top)
                Text(Format.coinsShort(prizes[i]))
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(.white)
                    .offset(y: -108)
                    .rotationEffect(.degrees(Double(i) * 45))
            }
        }
        .overlay(Circle().stroke(Theme.gold, lineWidth: 6))
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
        // Land the top pointer on the center of the winning slice (slice i is
        // centered at i*45° clockwise from the top).
        let sliceCenter = Double(slice) * 45.0
        // Normalize current angle out, add 5 full turns, then settle so the
        // wheel always spins forward regardless of the previous rest position.
        let base = angle - angle.truncatingRemainder(dividingBy: 360)
        let target = base + 360.0 * 5 - sliceCenter
        withAnimation(.easeOut(duration: 3.2)) {
            angle = target
        }
        try? await Task.sleep(nanoseconds: 3_300_000_000)
        Haptics.celebrate()
        withAnimation { showReward = true }
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
        // slice i spans [i*per, (i+1)*per), with 0 at the top (pointer)
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
