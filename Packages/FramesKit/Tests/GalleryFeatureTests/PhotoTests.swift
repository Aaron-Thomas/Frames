import Foundation
import Testing
@testable import GalleryFeature
@testable import ImagePipeline
import TestHelpers

struct PhotoTests {
    @Test func captionPrefersAltDescription() {
        #expect(Photo.mock(altDescription: "a red door", description: "Front door").caption == "A red door")
    }

    @Test func captionFallsBackToDescription() {
        #expect(Photo.mock(altDescription: nil, description: "Front door").caption == "Front door")
    }

    @Test func blankAltDescriptionFallsBack() {
        #expect(Photo.mock(altDescription: "  ", description: "Front door").caption == "Front door")
    }

    @Test func missingTextUsesPlaceholder() {
        #expect(Photo.mock(altDescription: nil, description: "").caption == "Untitled photo")
    }

    @Test(arguments: [(200, "thumb"), (201, "small"), (400, "small"), (401, "regular"), (1080, "regular")])
    func renditionCoversPixelWidth(pixelWidth: Int, rendition: String) {
        let request = Photo.mock().imageRequest(pixelWidth: pixelWidth)
        #expect(request.url.lastPathComponent == "\(rendition).jpg")
        #expect(request.targetPixelSize == pixelWidth)
    }
}
