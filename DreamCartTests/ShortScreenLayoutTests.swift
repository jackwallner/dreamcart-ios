import CoreGraphics
import XCTest
@testable import DreamCart

/// On a short screen (a Duo pane, the outer display) nothing may rest half
/// under a bottom bar: the product specs, the last cart row, the last chip.
final class ShortScreenLayoutTests: XCTestCase {
    // MARK: Product detail

    func testTallPhoneKeepsTheFullWidthPhoto() {
        // An iPhone 17 Pro: 402 pt wide, about 700 pt between the bars.
        XCTAssertNil(DetailHeroLayout.hero(visible: CGSize(width: 402, height: 700), infoHeight: 150))
    }

    func testDuoPaneEndsTheFirstScreenOnTheTags() throws {
        // The leading Duo pane: about 440 x 484 pt between the bars.
        let visible = CGSize(width: 440, height: 484)
        let info: CGFloat = 143
        let hero = try XCTUnwrap(DetailHeroLayout.hero(visible: visible, infoHeight: info))
        let pad = DetailHeroLayout.padding, gap = DetailHeroLayout.spacing
        // The tags end one padding above the bar...
        XCTAssertEqual(pad + hero.photoHeight + gap + info, visible.height - pad, accuracy: 0.001)
        // ...and the spec card starts below it.
        XCTAssertGreaterThan(pad + hero.height + gap, visible.height)
        XCTAssertLessThan(hero.photoHeight, (visible.width - 2 * pad) / DetailHeroLayout.photoAspect)
    }

    func testOuterDisplayShrinksThePhoto() {
        let hero = DetailHeroLayout.hero(visible: CGSize(width: 380, height: 550), infoHeight: 180)
        XCTAssertNotNil(hero)
        XCTAssertEqual(hero?.photoHeight ?? 0, 550 - 32 - 18 - 180, accuracy: 0.001)
    }

    func testPhotoNeverShrinksBelowItsFloor() {
        let hero = DetailHeroLayout.hero(visible: CGSize(width: 440, height: 300), infoHeight: 200)
        XCTAssertEqual(hero?.photoHeight, DetailHeroLayout.minPhotoHeight)
    }

    func testDuoPanePhotoSpansTheContentWidth() throws {
        let visible = CGSize(width: 440, height: 484)
        let hero = try XCTUnwrap(DetailHeroLayout.hero(visible: visible, infoHeight: 143))
        let aspect = DetailHeroLayout.widePhotoAspect(visibleWidth: visible.width, photoHeight: hero.photoHeight)
        XCTAssertEqual(aspect * hero.photoHeight, visible.width - 2 * DetailHeroLayout.padding, accuracy: 0.001)
        XCTAssertGreaterThan(aspect, DetailHeroLayout.photoAspect)
    }

    func testWidePhotoNeverGoesNarrowerThanThePhonePhoto() {
        XCTAssertEqual(DetailHeroLayout.widePhotoAspect(visibleWidth: 300, photoHeight: 500), DetailHeroLayout.photoAspect)
        XCTAssertEqual(DetailHeroLayout.widePhotoAspect(visibleWidth: 300, photoHeight: 0), DetailHeroLayout.photoAspect)
    }

    func testNothingMeasuredKeepsThePhoneLayout() {
        XCTAssertNil(DetailHeroLayout.hero(visible: .zero, infoHeight: 143))
        XCTAssertNil(DetailHeroLayout.hero(visible: CGSize(width: 440, height: 484), infoHeight: 0))
    }

    // MARK: Cart

    func testThreeRowsStayRegularInADuoPane() {
        XCTAssertFalse(CartListLayout.isCompact(rows: 3, visibleHeight: 433))
    }

    func testFourRowsTightenAndFitWholeInADuoPane() {
        XCTAssertTrue(CartListLayout.isCompact(rows: 4, visibleHeight: 433))
        XCTAssertLessThanOrEqual(CartListLayout.compactHeight(rows: 4), 433)
    }

    func testTallPhoneKeepsRegularRows() {
        XCTAssertFalse(CartListLayout.isCompact(rows: 4, visibleHeight: 620))
        XCTAssertFalse(CartListLayout.isCompact(rows: 2, visibleHeight: 0))
    }

    func testCartRowsEndOnTheWalletPillBesideTheVerticalStatusBar() {
        // Unfolded, the Cart pane has the Duo's 84 pt vertical status bar on
        // its trailing side; the pill sits on that safe-area edge.
        XCTAssertEqual(CartListLayout.trailingPadding(safeAreaInset: 84), 0)
        // A phone keeps the usual 16 pt margin.
        XCTAssertEqual(CartListLayout.trailingPadding(safeAreaInset: 0), CartListLayout.regularPadding)
        XCTAssertEqual(CartListLayout.trailingPadding(safeAreaInset: 6), 10)
    }

    // MARK: Filter chips

    func testChipsThatFitAllShowWithoutMore() {
        let count = ChipOverflow.visibleCount(widths: [50, 70, 90], available: 226, spacing: 8, moreWidth: 80)
        XCTAssertEqual(count, 3)
    }

    func testOverflowLeavesRoomForMoreAndEndsOnAWholeChip() {
        // All, Bags, Bottoms, Dresses, Extras beside the sort button.
        let widths: [CGFloat] = [50, 69, 97, 94, 85]
        let available: CGFloat = 356, spacing: CGFloat = 8, more: CGFloat = 82
        let count = ChipOverflow.visibleCount(widths: widths, available: available, spacing: spacing, moreWidth: more)
        XCTAssertEqual(count, 3)
        let used = widths.prefix(count).reduce(0, +) + CGFloat(count) * spacing + more
        XCTAssertLessThanOrEqual(used, available)
        XCTAssertGreaterThan(used + widths[count] + spacing, available)
    }

    func testNoRoomShowsNoChips() {
        XCTAssertEqual(ChipOverflow.visibleCount(widths: [50, 70], available: 0, spacing: 8, moreWidth: 80), 0)
    }

    // MARK: First row in an unfolded pane

    func testTodayPaneFitsThreeWholeDropsAboveTheBar() throws {
        // The leading pane: 423 pt of content, about 290 pt from the shelf to the bar.
        let row = try XCTUnwrap(FirstScreenRow.row(width: 423, room: 290, caption: 100))
        XCTAssertEqual(row.columns, 3)
        // Whole cards fill the width exactly, so none is cut at the fold...
        let s = FirstScreenRow.spacing
        XCTAssertEqual(CGFloat(row.columns) * row.tileWidth + CGFloat(row.columns - 1) * s, 423, accuracy: 0.001)
        // ...and the row ends clear of the bar.
        XCTAssertLessThanOrEqual(row.tileHeight, 290 - FirstScreenRow.barGap)
    }

    func testTodayPaneMeasuredInRunOneKeepsThreeCards() throws {
        // run1 (2026-10-23): shelf at 278.3 pt, bar at 560.7 pt, 423 pt wide.
        // Three cards need 262.2 pt; a 20 pt gap dropped the shelf to four.
        let row = try XCTUnwrap(FirstScreenRow.row(width: 423, room: 560.7 - 278.3, caption: 100))
        XCTAssertEqual(row.columns, 3)
    }

    func testRoomierPaneKeepsLargerTiles() throws {
        let row = try XCTUnwrap(FirstScreenRow.row(width: 423, room: 400, caption: 52))
        XCTAssertEqual(row.columns, 2)
        XCTAssertEqual(row.tileHeight, FirstScreenRow.tileHeight(width: row.tileWidth, caption: 52), accuracy: 0.001)
    }

    func testTooShortRoomKeepsThePhoneLayout() {
        XCTAssertNil(FirstScreenRow.row(width: 423, room: 150, caption: 100))
        XCTAssertNil(FirstScreenRow.row(width: 0, room: 300, caption: 100))
        XCTAssertNil(FirstScreenRow.row(width: 423, room: 0, caption: 100))
    }
}
