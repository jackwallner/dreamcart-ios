import CoreGraphics

/// Geometry of the For You swipe deck: the front card plus the cards peeking
/// out above it. The peek gets its own strip at the top, so on a short screen
/// (the folded Duo, or a pane of the unfolded one) the cards behind never
/// rise into the header.
enum DeckLayout {
    /// The catalog art is 686x858, about 0.8 wide per tall.
    static let artAspect: CGFloat = 0.8
    /// Cards mounted at once: the front card and two behind it.
    static let depth = 3
    /// How much higher each card behind sits than the one in front of it.
    static let step: CGFloat = 18
    /// Height kept above the front card for the backmost card's peek.
    static var rise: CGFloat { step * CGFloat(depth - 1) }

    /// The largest card at the art's aspect that fits `size` below the peek
    /// strip: width-bound on tall screens, height-bound on short ones.
    static func cardSize(in size: CGSize) -> CGSize {
        let room = max(0, size.height - rise)
        let height = max(0, min(room, size.width / artAspect))
        return CGSize(width: min(size.width, height * artAspect), height: height)
    }

    /// The pass and add buttons' diameter, and their gap to the card.
    static let control: CGFloat = 64
    static let controlGap: CGFloat = 14
    /// Space between the two buttons when they sit in a row under the card.
    static let rowSpacing: CGFloat = 28

    /// Where the card and its two buttons go in the space below the header.
    /// Stacked, the buttons sit in a row under the card. Flanking, they sit
    /// either side of it, so in a wide, short pane (the unfolded Duo) the
    /// card takes the full height and the three fill the pane's width.
    struct Arrangement: Equatable {
        var card: CGSize
        var flanking: Bool
        /// Height of the deck's own region, from the top of the space.
        var deckHeight: CGFloat
        /// Centre line of the buttons, from the top of the space.
        var controlsY: CGFloat
        /// Space between the two buttons.
        var controlSpacing: CGFloat
    }

    static func arrangement(in size: CGSize, allowsFlanking: Bool) -> Arrangement {
        let stackedHeight = max(0, size.height - control - controlGap)
        let stacked = cardSize(in: CGSize(width: size.width, height: stackedHeight))
        let flanked = cardSize(in: CGSize(width: size.width - 2 * (control + controlGap), height: size.height))
        guard allowsFlanking, flanked.height > stacked.height else {
            return Arrangement(card: stacked, flanking: false, deckHeight: stackedHeight,
                               controlsY: stackedHeight + controlGap + control / 2,
                               controlSpacing: rowSpacing)
        }
        return Arrangement(card: flanked, flanking: true, deckHeight: size.height,
                           controlsY: rise + (size.height - rise) / 2,
                           controlSpacing: flanked.width + 2 * controlGap)
    }
}
