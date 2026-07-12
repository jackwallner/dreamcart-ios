import SwiftUI

struct CandyButton: View {
    let title: String
    var systemImage: String? = nil
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: { if enabled { Haptics.soft(); action() } }) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(.dcButton)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                enabled ? AnyShapeStyle(Theme.candy) : AnyShapeStyle(Color.gray.opacity(0.5)),
                in: RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
            .shadow(color: enabled ? Theme.pink.opacity(0.35) : .clear, radius: 12, y: 6)
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled)
    }
}

// Adds a satisfying press-scale to any button.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.dcSection)
                    .foregroundStyle(Theme.ink(scheme))
                if let subtitle {
                    Text(subtitle)
                        .font(.dcSub)
                        .foregroundStyle(Theme.subtle(scheme))
                }
            }
            Spacer()
            if let actionTitle, let action {
                Button(action: { Haptics.tap(); action() }) {
                    Text(actionTitle)
                        .font(.dcLabel)
                        .foregroundStyle(Theme.violet)
                }
            }
        }
    }
}

struct EmptyState: View {
    let icon: String
    let title: String
    let message: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.dcIconXL)
                .foregroundStyle(Theme.violet.opacity(0.7))
            Text(title)
                .font(.dcSection)
                .foregroundStyle(Theme.ink(scheme))
            Text(message)
                .font(.dcSub)
                .foregroundStyle(Theme.subtle(scheme))
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
    }
}

// Horizontal selectable chip used for category / brand filters.
struct FilterChip: View {
    let label: String
    let selected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: { Haptics.select(); action() }) {
            Text(label)
                .font(.dcBody)
                .foregroundStyle(selected ? .white : Theme.ink(scheme))
                .padding(.horizontal, 15).padding(.vertical, 9)
                .background(
                    selected ? AnyShapeStyle(Theme.candy) : AnyShapeStyle(.thinMaterial),
                    in: Capsule())
                .overlay(Capsule().strokeBorder(selected ? .clear : Theme.subtle(scheme).opacity(0.25)))
        }
        .buttonStyle(PressableStyle())
    }
}
