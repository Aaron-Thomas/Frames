import Foundation
import FramesCore
import GalleryFeature

public enum Scenario: String, CaseIterable, Sendable {
    case recorded
    case slow
    case offline
    case offlineWithCache
    case rateLimited

    var isOffline: Bool {
        self == .offline || self == .offlineWithCache
    }

    var latency: Duration {
        self == .slow ? .seconds(2) : .milliseconds(300)
    }

    public init?(launchArgument: String?) {
        guard let launchArgument else { return nil }
        self.init(rawValue: launchArgument)
    }

    /// Each run gets its own cache in memory, so one run never affects the next.
    public func makeFeedCache() -> any FeedCaching {
        InMemoryFeedCache(seedsRecordedPhotos: self == .offlineWithCache)
    }

    /// Offline scenarios may only use images already in the disk cache.
    public func imageClient(wrapping client: any HTTPClient) -> any HTTPClient {
        isOffline ? CacheOnlyHTTPClient(wrapped: client) : client
    }

    func error(forPage page: Int) -> (any Error)? {
        switch self {
        case .offline, .offlineWithCache:
            return URLError(.notConnectedToInternet)
        case .rateLimited where page > 2:
            return HTTPStatusError(statusCode: 403, isRateLimited: true)
        case .recorded, .slow, .rateLimited:
            return nil
        }
    }
}
