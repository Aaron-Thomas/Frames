import Foundation
import Testing
import FramesCore
@testable import GalleryFeature
import TestHelpers

struct UnsplashPhotoServiceTests {
    private let client = StubHTTPClient()

    private var service: UnsplashPhotoService {
        UnsplashPhotoService(accessKey: "key", client: client)
    }

    @Test func editorialRequestCarriesPageAndKey() async throws {
        await client.stub(data: Data("[]".utf8))
        _ = try await service.editorialPhotos(page: 2)
        let request = try #require(await client.requests.first)
        let components = try #require(request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) })
        #expect(components.host == "api.unsplash.com")
        #expect(components.path == "/photos")
        let expectedItems = [URLQueryItem(name: "page", value: "2"), URLQueryItem(name: "per_page", value: "30")]
        #expect(components.queryItems == expectedItems)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Client-ID key")
        #expect(request.value(forHTTPHeaderField: "Accept-Version") == "v1")
    }

    @Test func searchRequestCarriesQuery() async throws {
        await client.stub(data: Data("{\"total\": 0, \"total_pages\": 0, \"results\": []}".utf8))
        let page = try await service.searchPhotos(matching: "red cars", page: 1)
        let request = try #require(await client.requests.first)
        #expect(request.url?.path() == "/search/photos")
        #expect(request.url?.query()?.contains("query=red%20cars") == true)
        #expect(page.hasMore == false)
    }

    @Test func plusInQueryIsEscaped() async throws {
        await client.stub(data: Data("{\"total\": 0, \"total_pages\": 0, \"results\": []}".utf8))
        _ = try await service.searchPhotos(matching: "c++", page: 1)
        let request = try #require(await client.requests.first)
        #expect(request.url?.query()?.contains("query=c%2B%2B") == true)
    }

    @Test func exhaustedRateLimitThrows() async throws {
        await client.stub(data: Data(), statusCode: 403, headers: ["X-Ratelimit-Remaining": "0"])
        await #expect(throws: HTTPStatusError(statusCode: 403, isRateLimited: true)) {
            try await service.editorialPhotos(page: 1)
        }
    }
}
