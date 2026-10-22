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
        let height = min(room, size.width / artAspect)
        return CGSize(width: min(size.width, height * artAspect), height: height)
    }
}
