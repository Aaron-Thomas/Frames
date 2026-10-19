import Foundation
import GalleryFeature

/// Pages recorded from the live API with `scripts/record-pages.sh`. They repeat endlessly as new photos,
/// each repeat with its own IDs and image URLs, so scrolling far loads new images as the live feed would.
enum MockData {
    static let recordedPageCount = 3
    static let searchPageCount = 5

    static func editorialPage(_ page: Int) throws -> PhotoPage {
        let recordedPage = (page - 1) % recordedPageCount + 1
        let recorded = try PhotoPage(editorialData: try data(named: "editorial-\(recordedPage)"))
        return PhotoPage(photos: recorded.photos.renamed(forRepeat: (page - 1) / recordedPageCount), hasMore: true)
    }

    static func recordedPhotos() throws -> [Photo] {
        try (1...recordedPageCount).flatMap { page in try editorialPage(page).photos }
    }

    static func searchPage(_ page: Int) throws -> PhotoPage {
        let recorded = try PhotoPage(searchData: try data(named: "search"), page: 1)
        return PhotoPage(photos: recorded.photos.renamed(forRepeat: page - 1), hasMore: page < searchPageCount)
    }

    private static func data(named name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try Data(contentsOf: url)
    }
}

private extension [Photo] {
    func renamed(forRepeat repeatIndex: Int) -> [Photo] {
        repeatIndex == 0 ? self : map { photo in photo.copy(withID: "\(photo.id)-repeat\(repeatIndex)") }
    }
}
