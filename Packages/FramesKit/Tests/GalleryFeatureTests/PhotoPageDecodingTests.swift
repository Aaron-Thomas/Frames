import Foundation
import Testing
@testable import GalleryFeature

struct PhotoPageDecodingTests {
    private static let photoJSON = """
    {"id": "abc", "description": null, "alt_description": "a cat", "width": 300, "height": 200, "color": "#112233",
     "urls": {"raw": "https://images.test/raw", "full": "https://images.test/full", "regular": "https://images.test/regular",
              "small": "https://images.test/small?ixid=1&w=400", "thumb": "https://images.test/thumb"},
     "user": {"name": "Ada", "links": {"html": "https://unsplash.com/@ada"}}}
    """

    @Test func editorialPageDecodes() throws {
        let page = try PhotoPage(editorialData: Data("[\(Self.photoJSON)]".utf8))
        let photo = try #require(page.photos.first)
        #expect(photo.id == "abc")
        #expect(photo.caption == "A cat")
        #expect(photo.urls.small.absoluteString == "https://images.test/small?ixid=1&w=400")
        #expect(page.hasMore)
    }

    @Test func emptyEditorialPageHasNoMore() throws {
        #expect(try PhotoPage(editorialData: Data("[]".utf8)).hasMore == false)
    }

    @Test func malformedPhotosAreSkipped() throws {
        let page = try PhotoPage(editorialData: Data("[\(Self.photoJSON), {\"id\": \"no-urls\"}, 42]".utf8))
        #expect(page.photos.map(\.id) == ["abc"])
        #expect(page.hasMore)
    }

    @Test(arguments: [(1, true), (3, false)])
    func searchPageKnowsWhenMoreRemain(page: Int, hasMore: Bool) throws {
        let json = "{\"total\": 61, \"total_pages\": 3, \"results\": [\(Self.photoJSON)]}"
        let decoded = try PhotoPage(searchData: Data(json.utf8), page: page)
        #expect(decoded.photos.count == 1)
        #expect(decoded.hasMore == hasMore)
    }
}
