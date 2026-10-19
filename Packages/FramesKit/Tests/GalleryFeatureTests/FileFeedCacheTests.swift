import Foundation
import Testing
import FramesCore
import GalleryFeature
import TestHelpers

struct FileFeedCacheTests {
    private let fileURL = URL.uniqueTemporaryFile()

    @Test func savedPhotosRoundTrip() async {
        let cache = FileFeedCache(fileURL: fileURL)
        let saved = LoadedValue(value: Photo.mocks(3), loadedAt: Date(timeIntervalSince1970: 100))
        await cache.save(saved)
        #expect(await FileFeedCache(fileURL: fileURL).savedPhotos() == saved)
    }

    @Test func missingFileHasNoSavedPhotos() async {
        #expect(await FileFeedCache(fileURL: fileURL).savedPhotos() == nil)
    }
}
