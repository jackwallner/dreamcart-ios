import UIKit

// Tactile feedback is core to the dopamine loop — every reward and tap lands.
enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func soft() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func rigid() { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func select() { UISelectionFeedbackGenerator().selectionChanged() }

    /// A rising celebratory burst for checkout / jackpot.
    static func celebrate() {
        let g = UIImpactFeedbackGenerator(style: .heavy)
        for (i, delay) in [0.0, 0.09, 0.18, 0.30].enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                g.impactOccurred(intensity: 0.6 + Double(i) * 0.13)
            }
        }
    }

    /// A quick "is it good?" tick fired a few times while a reveal builds
    /// suspense — the heartbeat before the payoff. `intensity` (0...1) ramps
    /// louder as the reveal gets closer.
    static func anticipationTick(intensity: Double) {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: max(0.15, min(1, intensity)))
    }

    /// Fired once per item as it's revealed during a multi-item unboxing.
    /// Intensity and impact style both ramp up across `step` so the last
    /// item in the haul lands hardest, feeding into the finale.
    static func escalate(step: Int, of total: Int) {
        let progress = total > 1 ? Double(step) / Double(total - 1) : 1
        let isLast = step == total - 1
        let g = UIImpactFeedbackGenerator(style: isLast ? .heavy : .rigid)
        g.impactOccurred(intensity: 0.5 + progress * 0.5)
        guard isLast else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 1)
        }
    }

    /// The finale for a completed haul — bigger and longer than `celebrate()`.
    static func jackpot() {
        let g = UIImpactFeedbackGenerator(style: .heavy)
        for (i, delay) in [0.0, 0.08, 0.16, 0.26, 0.4].enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                g.impactOccurred(intensity: 0.5 + Double(i) * 0.12)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
