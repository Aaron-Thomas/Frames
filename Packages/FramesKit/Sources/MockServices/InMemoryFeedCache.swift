import Foundation
import FramesCore
import GalleryFeature

actor InMemoryFeedCache: FeedCaching {
    private var saved: LoadedValue<[Photo]>?
    private var seedsRecordedPhotos: Bool

    init(seedsRecordedPhotos: Bool) {
        self.seedsRecordedPhotos = seedsRecordedPhotos
    }

    func savedPhotos() -> LoadedValue<[Photo]>? {
        if seedsRecordedPhotos {
            seedsRecordedPhotos = false
            saved = try? LoadedValue(value: MockData.recordedPhotos(), loadedAt: .now.addingTimeInterval(-2 * 60 * 60))
        }
        return saved
    }

    func save(_ photos: LoadedValue<[Photo]>) {
        saved = photos
    }
}
