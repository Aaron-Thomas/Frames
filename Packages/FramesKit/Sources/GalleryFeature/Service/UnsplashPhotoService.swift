import Foundation
import FramesCore

public struct UnsplashPhotoService: PhotoService {
    static let pageSize = 30

    private let accessKey: String
    private let client: any HTTPClient

    public init(accessKey: String, client: any HTTPClient) {
        self.accessKey = accessKey
        self.client = client
    }

    public func editorialPhotos(page: Int) async throws -> PhotoPage {
        try PhotoPage(editorialData: try await data(path: "/photos", page: page))
    }

    public func searchPhotos(matching query: String, page: Int) async throws -> PhotoPage {
        let queryItem = URLQueryItem(name: "query", value: query)
        let data = try await data(path: "/search/photos", page: page, extraItems: [queryItem])
        return try PhotoPage(searchData: data, page: page)
    }

    private func data(path: String, page: Int, extraItems: [URLQueryItem] = []) async throws -> Data {
        let queryItems = extraItems + [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(Self.pageSize))
        ]
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.unsplash.com"
        components.path = path
        components.queryItems = queryItems
        // URLComponents leaves "+" as is, and servers read it as a space.
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        guard let url = components.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.setValue("Client-ID \(accessKey)", forHTTPHeaderField: "Authorization")
        request.setValue("v1", forHTTPHeaderField: "Accept-Version")
        return try await client.validatedData(for: request)
    }
}
