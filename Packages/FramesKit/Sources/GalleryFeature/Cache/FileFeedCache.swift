import Foundation
import FramesCore

public actor FileFeedCache: FeedCaching {
    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func savedPhotos() -> LoadedValue<[Photo]>? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(LoadedValue<[Photo]>.self, from: data)
    }

    public func save(_ photos: LoadedValue<[Photo]>) {
        try? JSONEncoder().encode(photos).write(to: fileURL, options: .atomic)
    }
}
