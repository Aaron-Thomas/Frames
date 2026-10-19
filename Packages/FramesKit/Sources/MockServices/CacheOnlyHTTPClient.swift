import Foundation
import FramesCore

struct CacheOnlyHTTPClient: HTTPClient {
    let wrapped: any HTTPClient

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var cacheOnly = request
        cacheOnly.cachePolicy = .returnCacheDataDontLoad
        return try await wrapped.send(cacheOnly)
    }
}
