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
    var icon: String? = nil
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: { Haptics.select(); action() }) {
            FilterChipLabel(label: label, icon: icon, selected: selected)
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// A filter chip's capsule, shared with chips that open a menu.
struct FilterChipLabel: View {
    let label: String
    var icon: String? = nil
    var trailingIcon: String? = nil
    let selected: Bool
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 6) {
            if let icon, !icon.isEmpty, UIImage(systemName: icon) != nil {
                Image(systemName: icon)
                    .font(.dcIconS)
            }
            Text(label)
                .font(.dcBody)
                .lineLimit(1)
            if let trailingIcon {
                Image(systemName: trailingIcon)
                    .font(.dcCaption)
            }
        }
        .fixedSize()
        .foregroundStyle(selected ? .white : Theme.ink(scheme))
        .padding(.horizontal, 15).padding(.vertical, 9)
        .background(
            selected ? AnyShapeStyle(Theme.candy) : AnyShapeStyle(.thinMaterial),
            in: Capsule())
        .overlay(Capsule().strokeBorder(selected ? .clear : Theme.subtle(scheme).opacity(0.25)))
    }
}

extension View {
    /// Reports the size a scroll view shows between its bars: its bounds less
    /// the content insets (navigation bar, safe area, a bottom bar's inset).
    /// Close for a bar inset on an enclosing view (the Cart), but a
    /// `safeAreaInset` on the scroll view itself is overcounted, so product
    /// detail measures the buy bar's frame instead. iOS 18 and later; on
    /// iOS 17 nothing is reported and screens keep their phone layout.
    @ViewBuilder
    func onVisibleScrollSize(_ action: @escaping (CGSize) -> Void) -> some View {
        if #available(iOS 18.0, *) {
            onScrollGeometryChange(for: CGSize.self) { geometry in
                CGSize(
                    width: geometry.containerSize.width - geometry.contentInsets.leading - geometry.contentInsets.trailing,
                    height: geometry.containerSize.height - geometry.contentInsets.top - geometry.contentInsets.bottom
                )
            } action: { _, size in
                action(size)
            }
        } else {
            self
        }
    }
}

/// Whether a vertical scroll view rests at its top, as laid out, so a screen
/// measures its first-screen rows there and not at whatever offset a scroll
/// or pull passes through. Until someone scrolls it counts as resting, in
/// case the reported insets never quite match the resting offset.
private struct ScrollRestTracker: ViewModifier {
    @Binding var isAtRest: Bool
    @State private var isOffTop = false
    @State private var wasScrolled = false

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    abs(geometry.contentOffset.y + geometry.contentInsets.top) > 1
                } action: { _, offTop in
                    isOffTop = offTop
                    update()
                }
                .onScrollPhaseChange { _, phase in
                    if phase != .idle { wasScrolled = true }
                    update()
                }
        } else {
            content
        }
    }

    private func update() {
        isAtRest = !wasScrolled || !isOffTop
    }
}

extension View {
    func tracksScrollRest(_ isAtRest: Binding<Bool>) -> some View {
        modifier(ScrollRestTracker(isAtRest: isAtRest))
    }

    /// Reports this view's window frame while its scroll view rests at the top.
    func onRestingFrame(isAtRest: Bool, _ action: @escaping (CGRect) -> Void) -> some View {
        onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
            if isAtRest { action(frame) }
        }
    }
}
