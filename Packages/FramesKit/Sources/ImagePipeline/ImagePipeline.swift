import OSLog
import UIKit
import FramesCore

@MainActor
public final class ImagePipeline: ImageLoading {
    nonisolated static let signposter = OSSignposter(subsystem: "Frames", category: .pointsOfInterest)

    private var inFlight: [ImageRequest: InFlightLoad] = [:]
    private var prefetchTasks: [ImageRequest: Task<Void, Never>] = [:]
    private let memoryCache = NSCache<NSString, UIImage>()
    private let client: any HTTPClient

    public init(client: any HTTPClient, memoryLimit: Int, memoryWarnings: NotificationCenter) {
        self.client = client
        memoryCache.totalCostLimit = memoryLimit
        // One pipeline lives as long as the app, so the observer is never removed.
        _ = memoryWarnings.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.memoryCache.removeAllObjects() }
        }
    }

    public func cachedImage(for request: ImageRequest) -> UIImage? {
        memoryCache.object(forKey: request.cacheKey)
    }

    public func image(for request: ImageRequest) async throws -> UIImage {
        if let cached = cachedImage(for: request) {
            Self.signposter.emitEvent("Memory cache hit")
            return cached
        }
        // An item that scrolled away before asking starts no load.
        try Task.checkCancellation()
        let load: InFlightLoad
        if let existing = inFlight[request] {
            Self.signposter.emitEvent("Joined in-flight load")
            load = existing
        } else {
            load = startLoad(for: request)
        }
        load.subscriberCount += 1
        defer { finish(load, for: request) }
        let image = try await withTaskCancellationHandler {
            try await load.task.value
        } onCancel: {
            Task { @MainActor in self.unsubscribe(load, from: request) }
        }
        // Every caller stores it, so a caller that resumes late can't lose a finished image.
        memoryCache.setObject(image, forKey: request.cacheKey, cost: image.decodedByteCount)
        return image
    }

    public func prefetch(_ requests: [ImageRequest]) {
        let wanted = Set(requests)
        for (request, task) in prefetchTasks where !wanted.contains(request) {
            task.cancel()
            prefetchTasks[request] = nil
        }
        for request in requests where prefetchTasks[request] == nil && cachedImage(for: request) == nil {
            prefetchTasks[request] = Task(priority: .utility) { [self] in
                _ = try? await image(for: request)
            }
        }
    }

    func subscriberCount(for request: ImageRequest) -> Int {
        inFlight[request]?.subscriberCount ?? 0
    }

    private func startLoad(for request: ImageRequest) -> InFlightLoad {
        let task = Task.detached(priority: Task.currentPriority) { [self] in
            try await fetchImage(for: request)
        }
        let load = InFlightLoad(task: task)
        inFlight[request] = load
        return load
    }

    private func unsubscribe(_ load: InFlightLoad, from request: ImageRequest) {
        // A cancel can arrive after the load has finished and been removed.
        guard inFlight[request] === load else { return }
        load.subscriberCount -= 1
        guard load.subscriberCount == 0 else { return }
        Self.signposter.emitEvent("Load cancelled")
        load.task.cancel()
        finish(load, for: request)
    }

    private func finish(_ load: InFlightLoad, for request: ImageRequest) {
        if inFlight[request] === load {
            inFlight[request] = nil
        }
    }

    /// Image URLs never change content, so a cached response is always valid and never revalidated.
    private nonisolated func fetchImage(for request: ImageRequest) async throws -> UIImage {
        // Loads overlap, so each interval needs its own ID for Instruments to pair its start and end.
        let interval = Self.signposter.beginInterval("Image load", id: Self.signposter.makeSignpostID())
        defer { Self.signposter.endInterval("Image load", interval) }
        let urlRequest = URLRequest(url: request.url, cachePolicy: .returnCacheDataElseLoad)
        let data = try await client.validatedData(for: urlRequest)
        try Task.checkCancellation()
        guard let image = ImageDecoder.decode(data, targetPixelSize: request.targetPixelSize) else {
            throw URLError(.cannotDecodeContentData)
        }
        return image
    }
}

@MainActor
private final class InFlightLoad {
    let task: Task<UIImage, any Error>
    var subscriberCount = 0

    init(task: Task<UIImage, any Error>) {
        self.task = task
    }
}

private extension UIImage {
    var decodedByteCount: Int {
        cgImage.map { image in image.bytesPerRow * image.height } ?? 0
    }
}
