import CoreGraphics

/// Short screens (a 669 pt iPhone Duo pane, the 678 pt outer display) must
/// never rest with a card half under a bottom bar. Each screen decides from
/// the height its scroll view really shows: the scroll view's size less its
/// content insets (the navigation bar above, the buy, checkout or tab bar
/// below).

/// Product detail: when the full-width photo would push the specs under the
/// buy bar, the photo shrinks so the photo, brand, name, description and tags
/// fill the first screen whole, and the spec card starts below the bar.
enum DetailHeroLayout {
    static let padding: CGFloat = 16
    static let spacing: CGFloat = 18
    static let photoAspect: CGFloat = 0.82
    static let minPhotoHeight: CGFloat = 180

    struct Hero: Equatable {
        /// Cap on the photo's height (its width follows the aspect).
        var photoHeight: CGFloat
        /// Height the photo and info block take, so what follows starts one
        /// spacing below the visible area.
        var height: CGFloat
    }

    /// Nil when the phone layout already fits, or before anything is measured.
    static func hero(visible: CGSize, infoHeight: CGFloat) -> Hero? {
        guard visible.width > 0, visible.height > 0, infoHeight > 0 else { return nil }
        let natural = (visible.width - 2 * padding) / photoAspect
        // Top padding, photo, spacing, info, and the same padding as breathing
        // room above the bar.
        let room = visible.height - 2 * padding - spacing - infoHeight
        guard room < natural else { return nil }
        return Hero(photoHeight: max(minPhotoHeight, room), height: visible.height - padding)
    }

    /// In an unfolded Duo pane the capped photo keeps the full content width
    /// (the whole piece shown on a wash of its art), never narrower than the
    /// phone photo's aspect.
    static func widePhotoAspect(visibleWidth: CGFloat, photoHeight: CGFloat) -> CGFloat {
        guard photoHeight > 0 else { return photoAspect }
        return max(photoAspect, (visibleWidth - 2 * padding) / photoHeight)
    }
}

/// Cart: rows tighten when the regular ones would leave the last row cut by
/// the checkout bar.
enum CartListLayout {
    static let regularRow: CGFloat = 106 // 82 pt photo + 12 pt padding each side
    static let regularSpacing: CGFloat = 12
    static let regularPadding: CGFloat = 16
    static let compactRow: CGFloat = 88 // 68 pt photo + 10 pt padding each side
    static let compactSpacing: CGFloat = 8
    static let compactVerticalPadding: CGFloat = 12

    static func regularHeight(rows: Int) -> CGFloat {
        listHeight(rows: rows, row: regularRow, spacing: regularSpacing, padding: regularPadding)
    }

    static func compactHeight(rows: Int) -> CGFloat {
        listHeight(rows: rows, row: compactRow, spacing: compactSpacing, padding: compactVerticalPadding)
    }

    /// Trailing padding inside the safe area. The navigation bar puts its
    /// trailing item (the wallet pill) on the safe-area edge once the inset
    /// passes the usual margin, as beside the unfolded Duo's vertical status
    /// bar (84 pt). The rows end on that same edge rather than a further
    /// 16 pt in, so they line up with the pill.
    static func trailingPadding(safeAreaInset inset: CGFloat) -> CGFloat {
        max(regularPadding - max(inset, 0), 0)
    }

    static func isCompact(rows: Int, visibleHeight: CGFloat) -> Bool {
        guard rows > 0, visibleHeight > 0 else { return false }
        return regularHeight(rows: rows) > visibleHeight
    }

    private static func listHeight(rows: Int, row: CGFloat, spacing: CGFloat, padding: CGFloat) -> CGFloat {
        guard rows > 0 else { return 2 * padding }
        return 2 * padding + CGFloat(rows) * row + CGFloat(rows - 1) * spacing
    }
}

/// A row of filter chips that never ends on a cut-off chip: chips that do not
/// fit whole move into a trailing "More" menu.
enum ChipOverflow {
    /// How many leading chips show. All of them when they fit; otherwise the
    /// most that fit whole with the "More" chip after them.
    static func visibleCount(widths: [CGFloat], available: CGFloat,
                             spacing: CGFloat, moreWidth: CGFloat) -> Int {
        guard available > 0 else { return 0 }
        if rowWidth(widths, spacing: spacing) <= available { return widths.count }
        var used = moreWidth
        var count = 0
        for width in widths {
            used += spacing + width
            if used > available { break }
            count += 1
        }
        return count
    }

    private static func rowWidth(_ widths: [CGFloat], spacing: CGFloat) -> CGFloat {
        widths.reduce(0, +) + CGFloat(max(0, widths.count - 1)) * spacing
    }
}

/// The first row of product tiles in an unfolded Duo pane (Today's Just
/// dropped shelf, the Closet grid). It must rest whole above the floating tab
/// bar, never cut flat against it, and fill the content width with whole
/// tiles rather than end on a card cut at the fold.
enum FirstScreenRow {
    static let spacing: CGFloat = 12
    /// Clear space kept between the row and the tab bar. The caption block
    /// already ends in reserved space below the price. At 20 pt, three Today
    /// cards missed by 0.1 pt and the shelf fell to four narrow ones.
    static let barGap: CGFloat = 12
    static let artAspect: CGFloat = 0.82
    static let columnChoices = 2...4

    struct Row: Equatable {
        var columns: Int
        var tileWidth: CGFloat
        var tileHeight: CGFloat
    }

    /// Tile height for a width: art at the tile aspect plus the caption block.
    static func tileHeight(width: CGFloat, caption: CGFloat) -> CGFloat {
        width / artAspect + caption
    }

    /// The fewest columns (so the largest tiles) whose row fits whole in
    /// `room`, the height from the row's top to the tab bar. Nil when nothing
    /// is measured yet or even the smallest tiles would not fit, so the
    /// screen keeps its phone layout.
    static func row(width: CGFloat, room: CGFloat, caption: CGFloat) -> Row? {
        guard width > 0, room > 0 else { return nil }
        for columns in columnChoices {
            let tile = (width - spacing * CGFloat(columns - 1)) / CGFloat(columns)
            let height = tileHeight(width: tile, caption: caption)
            if height <= room - barGap {
                return Row(columns: columns, tileWidth: tile, tileHeight: height)
            }
        }
        return nil
    }
}
