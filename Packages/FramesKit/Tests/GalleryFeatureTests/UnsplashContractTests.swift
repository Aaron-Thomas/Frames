import Foundation
import Testing
@testable import GalleryFeature

private let accessKey = ProcessInfo.processInfo.environment["UNSPLASH_ACCESS_KEY"].flatMap { key in
    key.isEmpty || key.hasPrefix("$(") ? nil : key
}

/// Checks the live API still matches what the app decodes. Runs only when a key is configured, and costs two requests.
@Suite(.enabled(if: accessKey != nil, "Set UNSPLASH_ACCESS_KEY in Config/Secrets.xcconfig to run"))
struct UnsplashContractTests {
    private let service = UnsplashPhotoService(accessKey: accessKey ?? "", client: URLSession.shared)

    @Test func editorialPageDecodesEveryPhoto() async throws {
        let page = try await service.editorialPhotos(page: 1)
        #expect(page.photos.count == UnsplashPhotoService.pageSize)
    }

    @Test func searchPageDecodesEveryPhoto() async throws {
        let page = try await service.searchPhotos(matching: "nature", page: 1)
        #expect(page.photos.count == UnsplashPhotoService.pageSize)
        #expect(page.hasMore)
    }
}
