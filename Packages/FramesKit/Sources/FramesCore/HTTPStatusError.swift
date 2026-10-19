import Foundation

public struct HTTPStatusError: Error, Equatable {
    let statusCode: Int
    let isRateLimited: Bool

    public init(statusCode: Int, isRateLimited: Bool = false) {
        self.statusCode = statusCode
        self.isRateLimited = isRateLimited
    }

    init(_ response: HTTPURLResponse) {
        let remaining = response.value(forHTTPHeaderField: "X-Ratelimit-Remaining")
        self.init(statusCode: response.statusCode, isRateLimited: response.statusCode == 403 && remaining == "0")
    }
}
