import Foundation
import ImagePipeline

public struct Photo: Identifiable, Hashable, Sendable, Codable {
    struct URLs: Hashable, Sendable, Codable {
        let thumb: URL
        let small: URL
        let regular: URL
    }

    struct User: Hashable, Sendable, Codable {
        struct Links: Hashable, Sendable, Codable {
            let html: URL?
        }

        let name: String
        let links: Links?

        var profileURL: URL? {
            links?.html?.appending(queryItems: Photo.referralQueryItems)
        }

        init(name: String, profileURL: URL?) {
            self.name = name
            links = Links(html: profileURL)
        }
    }

    static let referralQueryItems = [
        URLQueryItem(name: "utm_source", value: "frames"),
        URLQueryItem(name: "utm_medium", value: "referral")
    ]

    public private(set) var id: String
    let description: String?
    let altDescription: String?
    let width: Int?
    let height: Int?
    let color: String?
    private(set) var urls: URLs
    let user: User?

    var caption: String {
        let text = [altDescription, description]
            .lazy
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        guard let text else { return String(localized: "Untitled photo") }
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    var aspectRatio: CGFloat? {
        guard let width, let height, width > 0, height > 0 else { return nil }
        return CGFloat(width) / CGFloat(height)
    }

    /// A copy that reads as a new photo, with its own ID and image URLs, so caches treat it as new.
    public func copy(withID newID: String) -> Photo {
        let copyTag = [URLQueryItem(name: "copy", value: newID)]
        var copy = self
        copy.id = newID
        copy.urls = URLs(
            thumb: urls.thumb.appending(queryItems: copyTag),
            small: urls.small.appending(queryItems: copyTag),
            regular: urls.regular.appending(queryItems: copyTag)
        )
        return copy
    }

    /// Unsplash's renditions are 200, 400 and 1080 pixels wide. Pick the smallest that covers the view.
    func imageRequest(pixelWidth: Int) -> ImageRequest {
        let url = switch pixelWidth {
        case ...200: urls.thumb
        case ...400: urls.small
        default: urls.regular
        }
        return ImageRequest(url: url, targetPixelSize: pixelWidth)
    }

    /// The largest rendition, decoded at its full size.
    func fullScreenImageRequest() -> ImageRequest {
        imageRequest(pixelWidth: .max)
    }
}
