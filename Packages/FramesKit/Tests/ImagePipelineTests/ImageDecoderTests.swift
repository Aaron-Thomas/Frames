import Testing
@testable import ImagePipeline

struct ImageDecoderTests {
    @Test func shorterSideShrinksToTarget() {
        #expect(ImageDecoder.maxPixelSize(width: 1200, height: 800, targetPixelSize: 400) == 600)
    }

    @Test func portraitShorterSideShrinksToTarget() {
        #expect(ImageDecoder.maxPixelSize(width: 800, height: 1600, targetPixelSize: 400) == 800)
    }

    @Test func smallImagesKeepFullSize() {
        #expect(ImageDecoder.maxPixelSize(width: 300, height: 200, targetPixelSize: 400) == 300)
    }
}
