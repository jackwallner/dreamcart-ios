import SwiftUI

/// Pane frames for the unfolded iPhone Duo: the browsing tabs on the leading
/// side of the fold, the Cart on the trailing side, so no card straddles the
/// crease. `nil` keeps the single column (every ordinary iPhone, the folded
/// Duo, and the unfolded Duo held in portrait, where each half would be too
/// narrow for the phone layouts).
struct UnfoldedSplit: Equatable, Sendable {
    var primaryWidth: CGFloat
    var secondaryX: CGFloat
    var secondaryWidth: CGFloat

    /// Narrowest pane that still fits a two-column product grid and the tab bar.
    static let minimumPaneWidth: CGFloat = 360

    /// - Parameters:
    ///   - width: the container's width.
    ///   - fold: the vertical fold's leading and trailing edge in the same
    ///     coordinate space, or `nil` when the system reports none.
    static func make(width: CGFloat, isRegularWidth: Bool, fold: ClosedRange<CGFloat>?) -> UnfoldedSplit? {
        guard isRegularWidth, width >= minimumPaneWidth * 2 else { return nil }
        if let fold,
           fold.lowerBound >= minimumPaneWidth,
           width - fold.upperBound >= minimumPaneWidth {
            return UnfoldedSplit(
                primaryWidth: fold.lowerBound,
                secondaryX: fold.upperBound,
                secondaryWidth: width - fold.upperBound
            )
        }
        let half = (width / 2).rounded(.down)
        return UnfoldedSplit(primaryWidth: half, secondaryX: half, secondaryWidth: width - half)
    }
}

extension UnfoldedSplit {
    /// The iPad's version for the screens before the app: the brand on the
    /// leading side and one phone-width column on the trailing side. `nil` in
    /// a compact window (Split View, Slide Over), which keeps the single column.
    static func makePad(width: CGFloat, isRegularWidth: Bool) -> UnfoldedSplit? {
        guard isRegularWidth, width >= 640 else { return nil }
        let column = min(560, (width * 0.62).rounded(.down))
        let primary = width - column
        return UnfoldedSplit(primaryWidth: primary, secondaryX: primary, secondaryWidth: column)
    }
}

/// What the split is measured from: the container's width and its fold.
struct PaneGeometry: Equatable, Sendable {
    var width: CGFloat
    var fold: ClosedRange<CGFloat>?
}

extension GeometryProxy {
    /// The vertical fold's horizontal extent in this proxy's space. Inactive
    /// folds count too, so the panes don't jump while the device opens.
    func verticalFold() -> ClosedRange<CGFloat>? {
        guard #available(iOS 27.1, *) else { return nil }
        let fold = reservedRegions(kind: .division, options: .includeInactive)
            .map(\.frame)
            .first { $0.height > $0.width && $0.minX > 0 && $0.maxX < size.width }
        guard let fold else { return nil }
        return fold.minX...fold.maxX
    }
}
