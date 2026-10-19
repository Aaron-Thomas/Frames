import SwiftUI
import FramesCore

extension LoadFailure {
    public var title: LocalizedStringKey {
        switch self {
        case .offline: "You're offline"
        case .rateLimited: "Hourly limit reached"
        case .unauthorised: "Access key not accepted"
        case .unavailable: "Something went wrong"
        }
    }

    public var systemImage: String {
        switch self {
        case .offline: "wifi.slash"
        case .rateLimited: "hourglass"
        case .unauthorised: "key"
        case .unavailable: "exclamationmark.triangle"
        }
    }
}
