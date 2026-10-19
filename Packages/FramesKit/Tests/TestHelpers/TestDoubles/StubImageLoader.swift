import UIKit
import ImagePipeline

@MainActor
public final class StubImageLoader: ImageLoading {
    public private(set) var requests: [ImageRequest] = []
    public private(set) var prefetches: [[ImageRequest]] = []
    public var cachedImages: [ImageRequest: UIImage] = [:]
    private var gates: [ImageRequest: Gate] = [:]

    public init() {}

    public func hold(_ request: ImageRequest, until gate: Gate) {
        gates[request] = gate
    }

    public func cachedImage(for request: ImageRequest) -> UIImage? {
        cachedImages[request]
    }

    public func image(for request: ImageRequest) async throws -> UIImage {
        requests.append(request)
        await gates[request]?.wait()
        try Task.checkCancellation()
        return .mock(width: 10, height: 10)
    }

    public func prefetch(_ requests: [ImageRequest]) {
        prefetches.append(requests)
    }
}
