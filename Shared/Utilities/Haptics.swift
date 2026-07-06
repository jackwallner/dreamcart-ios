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
}
