import UIKit

@MainActor
public protocol ImageLoading: Sendable {
    func cachedImage(for request: ImageRequest) -> UIImage?
    func image(for request: ImageRequest) async throws -> UIImage
    /// Replaces the set of images to load ahead of the scroll. Requests no longer in the set are cancelled.
    func prefetch(_ requests: [ImageRequest])
}
