import SwiftUI

/// Widths for regular-width windows (iPad, any Split View size that is wide
/// enough). Phones and compact windows stay under every cap, so these change
/// nothing there.
enum IPadLayout {
    /// Browsing pages: shelves and grids. Wider than any iPad, so the content
    /// lines up with the large title and only stops growing on a bigger canvas.
    static let content: CGFloat = 1440
    /// A single reading column: the cart, the profile rows, the detail's text.
    static let column: CGFloat = 640
    /// Onboarding and the purchase screens.
    static let form: CGFloat = 520
    /// Narrowest tile in a regular-width product grid.
    static let tile: CGFloat = 180

    /// Two flexible columns on a phone or a compact window, as many tiles of
    /// at least `tile` points as fit in a regular one.
    static func productColumns(regular: Bool, spacing: CGFloat = 12) -> [GridItem] {
        if regular { return [GridItem(.adaptive(minimum: tile, maximum: 260), spacing: spacing)] }
        return [GridItem(.flexible(), spacing: spacing), GridItem(.flexible(), spacing: spacing)]
    }
}

extension View {
    /// Caps the view's width and centres it in the space it is offered.
    func readableWidth(_ maxWidth: CGFloat = IPadLayout.content) -> some View {
        frame(maxWidth: maxWidth).frame(maxWidth: .infinity)
    }
}

extension View {
    /// A centred form-sized sheet on iPad (540 pt wide), the usual sheet on a phone.
    @ViewBuilder
    func formSheetSizing() -> some View {
        if #available(iOS 18.0, *) {
            presentationSizing(.form)
        } else {
            self
        }
    }
}
