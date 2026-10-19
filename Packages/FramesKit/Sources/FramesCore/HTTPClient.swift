import Foundation

public protocol HTTPClient: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

extension HTTPClient {
    public func validatedData(for request: URLRequest) async throws -> Data {
        let (data, response) = try await send(request)
        guard (200..<300).contains(response.statusCode) else { throw HTTPStatusError(response) }
        return data
    }
}

extension URLSession: HTTPClient {
    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (data, httpResponse)
    }
}
