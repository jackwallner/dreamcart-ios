import SwiftUI

// On the unfolded iPhone Duo a sheet is centred on the whole inner display and
// sits across the fold. Inside a pane, `paneSheet` instead covers just that
// pane: the pane's `PaneCoverHost` draws the content over the pane's own
// navigation stack, so nothing nests a second stack inside the first.

struct PaneCover: Identifiable {
    let id: UUID
    let view: AnyView
}

/// The cover slot of the pane a view sits in, or nil outside the unfolded Duo.
struct PaneCovers {
    let present: @MainActor (PaneCover) -> Void
    let dismiss: @MainActor (UUID) -> Void
}

extension EnvironmentValues {
    @Entry var paneCovers: PaneCovers? = nil
    /// Closes the pane cover this view was presented in (nil inside a sheet).
    @Entry var closePaneCover: (@MainActor () -> Void)? = nil
}

/// `dismiss` for views that can arrive as a sheet or as a pane cover: it closes
/// whichever one presented them.
@propertyWrapper
struct PaneAwareDismiss: DynamicProperty {
    @Environment(\.dismiss) private var system
    @Environment(\.closePaneCover) private var pane

    init() {}

    @MainActor var wrappedValue: @MainActor () -> Void {
        if let pane { return pane }
        let system = system
        return { system() }
    }
}

/// Wraps one pane. Always present, so folding never rebuilds the pane; it only
/// hands out its cover slot while `isActive`.
struct PaneCoverHost<Content: View>: View {
    let isActive: Bool
    @ViewBuilder let content: Content
    @State private var covers: [PaneCover] = []
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        content
            .overlay {
                ZStack {
                    ForEach(covers) { cover in
                        cover.view
                            .background(Theme.bg(scheme).ignoresSafeArea())
                            .transition(.move(edge: .bottom))
                    }
                }
                .animation(.smooth(duration: 0.32), value: covers.map(\.id))
            }
            .environment(\.paneCovers, isActive ? PaneCovers(
                present: { cover in
                    covers.removeAll { $0.id == cover.id }
                    covers.append(cover)
                },
                dismiss: { id in covers.removeAll { $0.id == id } }
            ) : nil)
            // Folding closes the covers; their presenters fall back to sheets.
            .onChange(of: isActive) { _, active in
                if !active { covers.removeAll() }
            }
    }
}

private struct PaneSheet<Sheet: View>: ViewModifier {
    @Binding var isPresented: Bool
    let onDismiss: (() -> Void)?
    let sheet: () -> Sheet
    @State private var coverID = UUID()
    @Environment(\.paneCovers) private var paneCovers
    @Environment(\.floatingTabBarHeight) private var tabBarHeight
    @Environment(RouteCoordinator.self) private var router

    private var inPane: Bool { paneCovers != nil }
    private var covering: Bool { isPresented && inPane }

    private func close() {
        isPresented = false
        onDismiss?()
    }

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: Binding(get: { isPresented && !inPane }, set: { isPresented = $0 }),
                   onDismiss: onDismiss, content: sheet)
            .onChange(of: covering) { _, now in
                if now {
                    paneCovers?.present(PaneCover(
                        id: coverID,
                        view: AnyView(sheet().environment(\.closePaneCover, close))
                    ))
                } else {
                    paneCovers?.dismiss(coverID)
                }
                // Only the panes under the floating tab bar hide it; the Cart
                // pane has none beneath it.
                if tabBarHeight > 0 { router.setOverlayVisible(now) }
            }
            .onDisappear {
                guard covering else { return }
                paneCovers?.dismiss(coverID)
                if tabBarHeight > 0 { router.setOverlayVisible(false) }
            }
    }
}

extension View {
    func paneSheet<Sheet: View>(isPresented: Binding<Bool>,
                                onDismiss: (() -> Void)? = nil,
                                @ViewBuilder content: @escaping () -> Sheet) -> some View {
        modifier(PaneSheet(isPresented: isPresented, onDismiss: onDismiss, sheet: content))
    }
}
