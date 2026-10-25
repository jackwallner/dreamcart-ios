import CoreGraphics
import XCTest
@testable import DreamCart

/// The For You deck must keep the art's aspect and leave the cards behind
/// room to peek out without reaching the header above the deck.
final class DeckLayoutTests: XCTestCase {
    func testTallSpaceIsWidthBound() {
        let card = DeckLayout.cardSize(in: CGSize(width: 358, height: 560))
        XCTAssertEqual(card.width, 358, accuracy: 0.001)
        XCTAssertEqual(card.height, 447.5, accuracy: 0.001)
    }

    func testShortSpaceKeepsThePeekStrip() {
        // A Duo pane: wide but short.
        let size = CGSize(width: 443, height: 330)
        let card = DeckLayout.cardSize(in: size)
        XCTAssertEqual(card.height, size.height - DeckLayout.rise, accuracy: 0.001)
        XCTAssertEqual(card.width / card.height, DeckLayout.artAspect, accuracy: 0.001)
    }

    func testBackmostCardStaysInsideTheDeck() {
        // Front card centred in the space below the strip; each card behind is
        // scaled down 5% per slot about its centre and lifted one step.
        for size in [CGSize(width: 443, height: 330), CGSize(width: 358, height: 560), CGSize(width: 300, height: 200)] {
            let card = DeckLayout.cardSize(in: size)
            let frontTop = DeckLayout.rise + (size.height - DeckLayout.rise - card.height) / 2
            for slot in 1..<DeckLayout.depth {
                let scale = 1 - CGFloat(slot) * 0.05
                let top = frontTop + card.height * (1 - scale) / 2 - DeckLayout.step * CGFloat(slot)
                XCTAssertGreaterThanOrEqual(top, 0, "slot \(slot) in \(size)")
            }
        }
    }

    func testNoRoomGivesAnEmptyCard() {
        let card = DeckLayout.cardSize(in: CGSize(width: 300, height: 20))
        XCTAssertEqual(card, .zero)
    }

    func testPhoneKeepsTheButtonsUnderTheCard() {
        let size = CGSize(width: 361, height: 560)
        let layout = DeckLayout.arrangement(in: size, allowsFlanking: true)
        XCTAssertFalse(layout.flanking)
        XCTAssertEqual(layout.card, DeckLayout.cardSize(in: CGSize(width: 361, height: 560 - 78)))
        XCTAssertEqual(layout.controlsY, 560 - 32, accuracy: 0.001)
        XCTAssertEqual(layout.controlSpacing, DeckLayout.rowSpacing)
    }

    func testDuoPaneFlanksTheCardWithItsButtons() {
        // The unfolded Duo's leading pane below the For You header.
        let size = CGSize(width: 443, height: 408)
        let layout = DeckLayout.arrangement(in: size, allowsFlanking: true)
        XCTAssertTrue(layout.flanking)
        XCTAssertEqual(layout.card.width / layout.card.height, DeckLayout.artAspect, accuracy: 0.001)
        // Card plus a button and gap each side fits the pane's width.
        let row = layout.card.width + 2 * (DeckLayout.control + DeckLayout.controlGap)
        XCTAssertLessThanOrEqual(row, size.width + 0.001)
        // Taller than the stacked card it replaces.
        let stacked = DeckLayout.arrangement(in: size, allowsFlanking: false)
        XCTAssertGreaterThan(layout.card.height, stacked.card.height)
        // Buttons centred on the card, which is centred below the peek strip.
        XCTAssertEqual(layout.controlsY, DeckLayout.rise + (size.height - DeckLayout.rise) / 2, accuracy: 0.001)
        XCTAssertEqual(layout.controlSpacing, layout.card.width + 2 * DeckLayout.controlGap, accuracy: 0.001)
    }

    func testFoldedScreenNeverFlanks() {
        let size = CGSize(width: 434, height: 420)
        XCTAssertFalse(DeckLayout.arrangement(in: size, allowsFlanking: false).flanking)
    }
}
