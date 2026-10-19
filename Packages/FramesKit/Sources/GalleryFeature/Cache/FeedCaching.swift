import FramesCore

public protocol FeedCaching: Sendable {
    func savedPhotos() async -> LoadedValue<[Photo]>?
    func save(_ photos: LoadedValue<[Photo]>) async
}
