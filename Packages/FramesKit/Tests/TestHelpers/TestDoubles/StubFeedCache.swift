import FramesCore
import GalleryFeature

public actor StubFeedCache: FeedCaching {
    public private(set) var savedValues: [LoadedValue<[Photo]>] = []
    private let saved: LoadedValue<[Photo]>?

    public init(saved: LoadedValue<[Photo]>? = nil) {
        self.saved = saved
    }

    public func savedPhotos() -> LoadedValue<[Photo]>? {
        saved
    }

    public func save(_ photos: LoadedValue<[Photo]>) {
        savedValues.append(photos)
    }
}
