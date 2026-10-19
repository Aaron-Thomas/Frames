import Foundation

public enum LoadFailure: Equatable, Sendable {
    case offline
    case rateLimited
    case unauthorised
    case unavailable

    private static let offlineCodes: Set<URLError.Code> = [
        .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff
    ]

    public init(_ error: any Error) {
        switch error {
        case let urlError as URLError where Self.offlineCodes.contains(urlError.code):
            self = .offline
        case let statusError as HTTPStatusError where statusError.isRateLimited:
            self = .rateLimited
        case let statusError as HTTPStatusError where statusError.statusCode == 401:
            self = .unauthorised
        default:
            self = .unavailable
        }
    }
}
