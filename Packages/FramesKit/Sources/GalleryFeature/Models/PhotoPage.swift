import Foundation
import OSLog

public struct PhotoPage: Equatable, Sendable {
    public let photos: [Photo]
    let hasMore: Bool

    public init(photos: [Photo], hasMore: Bool) {
        self.photos = photos
        self.hasMore = hasMore
    }

    public init(editorialData data: Data) throws {
        let list = try JSONDecoder.unsplash.decode(LossyPhotoList.self, from: data)
        self.init(photos: list.photos, hasMore: list.itemCount > 0)
    }

    public init(searchData data: Data, page: Int) throws {
        let response = try JSONDecoder.unsplash.decode(SearchResponse.self, from: data)
        self.init(photos: response.results.photos, hasMore: page < response.totalPages)
    }
}

private struct SearchResponse: Decodable {
    let totalPages: Int
    let results: LossyPhotoList
}

/// A malformed photo is skipped and logged rather than failing the whole page.
private struct LossyPhotoList: Decodable {
    private struct Skipped: Decodable {
        init(from decoder: any Decoder) throws {}
    }

    private static let logger = Logger(subsystem: "Frames", category: "Decoding")

    let photos: [Photo]
    let itemCount: Int

    init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var photos: [Photo] = []
        while !container.isAtEnd {
            if let photo = try? container.decode(Photo.self) {
                photos.append(photo)
            } else {
                _ = try container.decode(Skipped.self)
            }
        }
        let itemCount = container.count ?? photos.count
        if itemCount > photos.count {
            Self.logger.warning("Skipped \(itemCount - photos.count) unreadable photos")
        }
        self.photos = photos
        self.itemCount = itemCount
    }
}

extension JSONDecoder {
    static var unsplash: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}
