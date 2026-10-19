import Foundation
import Testing
import FramesCore
import TestHelpers

struct LoadFailureTests {
    @Test(arguments: [URLError.Code.notConnectedToInternet, .networkConnectionLost, .dataNotAllowed])
    func connectionErrorsMeanOffline(code: URLError.Code) {
        #expect(LoadFailure(URLError(code)) == .offline)
    }

    @Test func exhaustedRateLimitIsRateLimited() {
        #expect(LoadFailure(HTTPStatusError(statusCode: 403, isRateLimited: true)) == .rateLimited)
    }

    @Test func unauthorisedStatusIsUnauthorised() {
        #expect(LoadFailure(HTTPStatusError(statusCode: 401)) == .unauthorised)
    }

    @Test func otherErrorsAreUnavailable() {
        #expect(LoadFailure(HTTPStatusError(statusCode: 500)) == .unavailable)
        #expect(LoadFailure(URLError(.badServerResponse)) == .unavailable)
    }

    @Test(arguments: [("12", false), ("0", true)])
    func forbiddenIsRateLimitedOnlyWithNoRequestsRemaining(remaining: String, isRateLimited: Bool) async {
        let client = StubHTTPClient()
        await client.stub(data: Data(), statusCode: 403, headers: ["X-Ratelimit-Remaining": remaining])
        let request = URLRequest(url: URL(filePath: "/photos"))
        await #expect(throws: HTTPStatusError(statusCode: 403, isRateLimited: isRateLimited)) {
            try await client.validatedData(for: request)
        }
    }
}
