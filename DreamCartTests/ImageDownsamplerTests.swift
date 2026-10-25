import CoreGraphics
import XCTest
@testable import DreamCart

/// Pollinations stamps its mark in the bottom-right corner of every render.
final class ImageDownsamplerTests: XCTestCase {
    func testTrimDropsTheWatermarkBand() {
        // A keyless render comes back 686 x 858 with the mark's white pixels
        // in rows 832...846 and its outline from about row 828.
        let kept = ImageDownsampler.unmarkedRect(width: 686, height: 858)
        XCTAssertEqual(kept.width, 686)
        XCTAssertLessThan(kept.maxY, 828)
        XCTAssertEqual(kept.minY, 0)
    }

    func testTrimKeepsMostOfTheImage() {
        let kept = ImageDownsampler.unmarkedRect(width: 700, height: 875)
        XCTAssertGreaterThan(kept.height, 875 * 0.9)
    }

    func testTinyImageKeepsAPixel() {
        XCTAssertEqual(ImageDownsampler.unmarkedRect(width: 1, height: 1).height, 1)
    }
}
