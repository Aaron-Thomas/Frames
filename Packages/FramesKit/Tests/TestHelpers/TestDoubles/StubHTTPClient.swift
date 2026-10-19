import Foundation
import FramesCore

public actor StubHTTPClient: HTTPClient {
    public struct NotStubbedError: Error {}

    private struct StubbedResponse: Sendable {
        let result: Result<(data: Data, statusCode: Int, headers: [String: String]), any Error>
        let gate: Gate?
    }

    public private(set) var requests: [URLRequest] = []
    public private(set) var cancelledCount = 0
    private var responses: ArraySlice<StubbedResponse> = []

    public init() {}

    public func stub(data: Data, statusCode: Int = 200, headers: [String: String] = [:], until gate: Gate? = nil) {
        responses.append(StubbedResponse(result: .success((data, statusCode, headers)), gate: gate))
    }

    public func stub(error: any Error, until gate: Gate? = nil) {
        responses.append(StubbedResponse(result: .failure(error), gate: gate))
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        guard let stubbed = responses.popFirst() else { throw NotStubbedError() }
        await stubbed.gate?.wait()
        if Task.isCancelled {
            cancelledCount += 1
            throw CancellationError()
        }
        let response = try stubbed.result.get()
        guard let url = request.url,
              let httpResponse = HTTPURLResponse(
                url: url,
                statusCode: response.statusCode,
                httpVersion: nil,
                headerFields: response.headers
              ) else {
            throw URLError(.badURL)
        }
        return (response.data, httpResponse)
    }
}
