import Foundation
import Testing
import UIKit
import FramesCore
@testable import ImagePipeline
import TestHelpers

@MainActor
struct ImagePipelineTests {
    private let client = StubHTTPClient()
    private let memoryWarnings = NotificationCenter()
    private let request = ImageRequest.mock(targetPixelSize: 100)
    private let jpeg = Data.mockJPEG(width: 200, height: 200)

    @Test func secondRequestComesFromMemory() async throws {
        await client.stub(data: jpeg)
        let pipeline = makePipeline()
        let first = try await pipeline.image(for: request)
        let second = try await pipeline.image(for: request)
        #expect(first === second)
        #expect(await client.requests.count == 1)
        #expect(pipeline.cachedImage(for: request) === first)
    }

    @Test func concurrentRequestsShareOneLoad() async throws {
        let (pipeline, gate, first, second) = await twoWaitingCallers()
        await gate.open()
        let (firstImage, secondImage) = try await (first.value, second.value)
        #expect(firstImage === secondImage)
        #expect(pipeline.cachedImage(for: request) === firstImage)
        #expect(await client.requests.count == 1)
    }

    @Test func cancellingOneCallerKeepsSharedLoad() async throws {
        let (pipeline, gate, leaving, staying) = await twoWaitingCallers()
        leaving.cancel()
        await waitUntil { pipeline.subscriberCount(for: request) == 1 }
        await gate.open()
        _ = try await staying.value
        #expect(await client.cancelledCount == 0)
    }

    @Test func cancellingEveryCallerCancelsRequest() async {
        let (pipeline, gate, first, second) = await twoWaitingCallers()
        first.cancel()
        second.cancel()
        await waitUntil { pipeline.subscriberCount(for: request) == 0 }
        await gate.open()
        #expect(await waitUntil { await client.cancelledCount == 1 })
        #expect(pipeline.cachedImage(for: request) == nil)
    }

    @Test func callerCancelledBeforeAskingStartsNoLoad() async {
        await client.stub(data: jpeg)
        let pipeline = makePipeline()
        let gate = Gate()
        let caller = Task {
            await gate.wait()
            return try await pipeline.image(for: request)
        }
        caller.cancel()
        await gate.open()
        await #expect(throws: CancellationError.self) { try await caller.value }
        #expect(pipeline.subscriberCount(for: request) == 0)
        #expect(await client.requests.isEmpty)
    }

    @Test func failuresAreNotCached() async throws {
        await client.stub(error: URLError(.notConnectedToInternet))
        await client.stub(data: jpeg)
        let pipeline = makePipeline()
        await #expect(throws: URLError.self) { try await pipeline.image(for: request) }
        _ = try await pipeline.image(for: request)
        #expect(await client.requests.count == 2)
    }

    @Test func requestsPreferCachedResponses() async throws {
        await client.stub(data: jpeg)
        _ = try await makePipeline().image(for: request)
        #expect(await client.requests.first?.cachePolicy == .returnCacheDataElseLoad)
    }

    @Test func memoryWarningEmptiesCache() async throws {
        await client.stub(data: jpeg)
        let pipeline = makePipeline()
        _ = try await pipeline.image(for: request)
        memoryWarnings.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        #expect(await waitUntil { pipeline.cachedImage(for: request) == nil })
    }

    @Test func imagesDecodeAtTargetSize() async throws {
        await client.stub(data: .mockJPEG(width: 1200, height: 800))
        let image = try await makePipeline().image(for: .mock(targetPixelSize: 400))
        #expect(image.cgImage?.width == 600)
        #expect(image.cgImage?.height == 400)
    }

    @Test func undecodableDataFails() async {
        await client.stub(data: Data("not an image".utf8))
        await #expect(throws: URLError(.cannotDecodeContentData)) { try await makePipeline().image(for: request) }
    }

    @Test func prefetchLoadsUncachedImages() async throws {
        await client.stub(data: jpeg)
        await client.stub(data: jpeg)
        let pipeline = makePipeline()
        let requests = [ImageRequest.mock("first"), .mock("second")]
        pipeline.prefetch(requests)
        await waitUntil { requests.allSatisfy { pipeline.subscriberCount(for: $0) == 1 } }
        // Joining each prefetch waits for its download and decode, however long they take.
        for request in requests {
            _ = try await pipeline.image(for: request)
        }
        #expect(requests.allSatisfy { pipeline.cachedImage(for: $0) != nil })
        #expect(await client.requests.count == 2)
    }

    @Test func prefetchSkipsCachedImages() async throws {
        await client.stub(data: jpeg)
        let pipeline = makePipeline()
        _ = try await pipeline.image(for: request)
        pipeline.prefetch([request])
        #expect(pipeline.subscriberCount(for: request) == 0)
        #expect(await client.requests.count == 1)
    }

    @Test func prefetchLeavingWindowIsCancelled() async {
        let gate = Gate()
        await client.stub(data: jpeg, until: gate)
        let pipeline = makePipeline()
        pipeline.prefetch([request])
        await waitUntil { pipeline.subscriberCount(for: request) == 1 }
        pipeline.prefetch([])
        await waitUntil { pipeline.subscriberCount(for: request) == 0 }
        await gate.open()
        #expect(await waitUntil { await client.cancelledCount == 1 })
    }

    @Test func itemJoiningPrefetchMakesOneRequest() async throws {
        let gate = Gate()
        await client.stub(data: jpeg, until: gate)
        let pipeline = makePipeline()
        pipeline.prefetch([request])
        await waitUntil { pipeline.subscriberCount(for: request) == 1 }
        let visibleItem = Task { try await pipeline.image(for: request) }
        await waitUntil { pipeline.subscriberCount(for: request) == 2 }
        pipeline.prefetch([])
        await gate.open()
        _ = try await visibleItem.value
        #expect(await client.requests.count == 1)
        #expect(await client.cancelledCount == 0)
    }

    @Test func prefetchKeepsRequestsStillInWindow() async {
        for _ in 0..<3 {
            await client.stub(data: jpeg)
        }
        let pipeline = makePipeline()
        pipeline.prefetch([.mock("first"), .mock("second")])
        pipeline.prefetch([.mock("second"), .mock("third")])
        await waitUntil { await client.requests.count == 3 }
        let secondRequests = await client.requests.filter { $0.url == ImageRequest.mock("second").url }
        #expect(secondRequests.count == 1)
    }

    private func makePipeline() -> ImagePipeline {
        ImagePipeline(client: client, memoryLimit: 10_000_000, memoryWarnings: memoryWarnings)
    }

    private typealias ImageTask = Task<UIImage, any Error>

    private func twoWaitingCallers() async -> (ImagePipeline, Gate, ImageTask, ImageTask) {
        let gate = Gate()
        await client.stub(data: jpeg, until: gate)
        let pipeline = makePipeline()
        let first = Task { try await pipeline.image(for: request) }
        let second = Task { try await pipeline.image(for: request) }
        await waitUntil { pipeline.subscriberCount(for: request) == 2 }
        return (pipeline, gate, first, second)
    }
}
