import Foundation
import Testing
import FramesCore
@testable import GalleryFeature
import ImagePipeline
import TestHelpers

@MainActor
struct PhotoFeedViewModelTests {
    private let service = StubPhotoService()
    private let loader = StubImageLoader()
    private let now = Date(timeIntervalSince1970: 1_000)
    private let firstPage = Photo.mocks(30, prefix: "first")
    private let secondPage = Photo.mocks(30, prefix: "second")
    private let saved = LoadedValue(value: Photo.mocks(5, prefix: "saved"), loadedAt: Date(timeIntervalSince1970: 10))

    @Test func firstPageLoads() async {
        await service.stub(.success(.mock(firstPage)))
        let viewModel = makeViewModel()
        await viewModel.load()
        #expect(viewModel.photos == firstPage)
        #expect(viewModel.state.lastLoaded?.loadedAt == now)
        #expect(await service.invocations == [.editorial(page: 1)])
    }

    @Test func photoNearEndLoadsNextPage() async {
        let viewModel = await loadedViewModel()
        await service.stub(.success(.mock(secondPage)))
        viewModel.photoAppeared(firstPage[18], pixelWidth: 400)
        await waitUntil { viewModel.photos.count == 60 }
        #expect(viewModel.photos == firstPage + secondPage)
        #expect(await service.invocations == [.editorial(page: 1), .editorial(page: 2)])
    }

    @Test func earlyPhotoDoesNotLoadNextPage() async {
        let viewModel = await loadedViewModel()
        viewModel.photoAppeared(firstPage[17], pixelWidth: 400)
        await settle()
        #expect(await service.invocations == [.editorial(page: 1)])
    }

    @Test func repeatedPhotosAreDropped() async {
        let viewModel = await loadedViewModel()
        await service.stub(.success(.mock([firstPage[29]] + secondPage)))
        viewModel.photoAppeared(firstPage[29], pixelWidth: 400)
        await waitUntil { viewModel.photos.count == 60 }
        #expect(viewModel.photos == firstPage + secondPage)
    }

    @Test func pageOfRepeatsLoadsTheNext() async {
        let viewModel = await loadedViewModel()
        await service.stub(.success(.mock(firstPage)))
        await service.stub(.success(.mock(secondPage)))
        viewModel.photoAppeared(firstPage[29], pixelWidth: 400)
        await waitUntil { viewModel.photos.count == 60 }
        #expect(await service.invocations == [.editorial(page: 1), .editorial(page: 2), .editorial(page: 3)])
    }

    @Test func onePageLoadsAtATime() async {
        let viewModel = await loadedViewModel()
        let gate = Gate()
        await service.stub(.success(.mock(secondPage)), until: gate)
        viewModel.photoAppeared(firstPage[20], pixelWidth: 400)
        viewModel.photoAppeared(firstPage[29], pixelWidth: 400)
        await gate.open()
        await waitUntil { viewModel.photos.count == 60 }
        #expect(await service.invocations == [.editorial(page: 1), .editorial(page: 2)])
    }

    @Test func lastPageStopsLoading() async {
        await service.stub(.success(.mock(firstPage, hasMore: false)))
        let viewModel = makeViewModel()
        await viewModel.load()
        viewModel.photoAppeared(firstPage[29], pixelWidth: 400)
        await settle()
        #expect(await service.invocations == [.editorial(page: 1)])
    }

    @Test func failedNextPageKeepsPhotos() async {
        let viewModel = await failedNextPageViewModel()
        #expect(viewModel.state.failure == .offline)
        #expect(viewModel.photos == firstPage)
    }

    @Test func failedNextPageWaitsForRetry() async {
        let viewModel = await failedNextPageViewModel()
        viewModel.photoAppeared(firstPage[29], pixelWidth: 400)
        await settle()
        #expect(await service.invocations == [.editorial(page: 1), .editorial(page: 2)])
    }

    @Test func failedFirstPageWaitsForRetry() async {
        await service.stub(.failure(URLError(.notConnectedToInternet)))
        let viewModel = makeViewModel()
        await viewModel.load()
        await viewModel.load()
        #expect(await service.invocations == [.editorial(page: 1)])
    }

    @Test func retryReloadsFailedPage() async {
        let viewModel = await failedNextPageViewModel()
        await service.stub(.success(.mock(secondPage)))
        viewModel.retry()
        await waitUntil { viewModel.photos.count == 60 }
        #expect(await service.invocations == [.editorial(page: 1), .editorial(page: 2), .editorial(page: 2)])
    }

    @Test func savedPhotosShowWhileRefreshing() async {
        let gate = Gate()
        await service.stub(.success(.mock(firstPage)), until: gate)
        let viewModel = makeViewModel(cache: StubFeedCache(saved: saved))
        let loading = Task { await viewModel.load() }
        await waitUntil { viewModel.photos.count == 5 }
        #expect(viewModel.isShowingSavedPhotos)
        await gate.open()
        await loading.value
        #expect(viewModel.photos == firstPage)
        #expect(!viewModel.isShowingSavedPhotos)
    }

    @Test func failedRefreshKeepsSavedPhotos() async {
        await service.stub(.failure(URLError(.notConnectedToInternet)))
        let viewModel = makeViewModel(cache: StubFeedCache(saved: saved))
        await viewModel.load()
        #expect(viewModel.photos == saved.value)
        #expect(viewModel.isShowingSavedPhotos)
        #expect(viewModel.state.failure == .offline)
        #expect(viewModel.state.lastLoaded?.loadedAt == saved.loadedAt)
    }

    @Test func retryAfterFailedRefreshStartsFromFirstPage() async {
        await service.stub(.failure(URLError(.notConnectedToInternet)))
        await service.stub(.success(.mock(firstPage)))
        let viewModel = makeViewModel(cache: StubFeedCache(saved: saved))
        await viewModel.load()
        viewModel.retry()
        await waitUntil { viewModel.photos == firstPage }
        #expect(await service.invocations == [.editorial(page: 1), .editorial(page: 1)])
    }

    @Test func firstFivePagesAreSaved() async {
        let cache = StubFeedCache()
        let pages = (1...6).map { page in Photo.mocks(30, prefix: "page\(page)") }
        for page in pages {
            await service.stub(.success(.mock(page)))
        }
        let viewModel = makeViewModel(cache: cache)
        await viewModel.load()
        for loadedPages in 1..<pages.count {
            viewModel.photoAppeared(viewModel.photos[viewModel.photos.count - 1], pixelWidth: 400)
            await waitUntil { viewModel.photos.count == (loadedPages + 1) * 30 }
        }
        let savedValues = await cache.savedValues
        #expect(savedValues.count == 5)
        #expect(savedValues.last?.value == pages.prefix(5).flatMap { $0 })
        #expect(savedValues.last?.loadedAt == now)
    }

    @Test func cancellationIsSilent() async {
        let gate = Gate()
        await service.stub(.success(.mock(firstPage)), until: gate)
        let viewModel = makeViewModel()
        let loading = Task { await viewModel.load() }
        await waitUntil { await service.invocations.count == 1 }
        loading.cancel()
        await gate.open()
        await loading.value
        #expect(viewModel.state == .idle)
        #expect(!viewModel.hasLoadedFromNetwork)
    }

    @Test func scrollingDownPrefetchesPhotosBelow() async {
        let viewModel = await loadedViewModel()
        viewModel.photoAppeared(firstPage[10], pixelWidth: 400)
        #expect(loader.prefetches.last == firstPage[11..<23].map { photo in photo.imageRequest(pixelWidth: 400) })
    }

    @Test func scrollingUpPrefetchesPhotosAbove() async {
        let viewModel = await loadedViewModel()
        viewModel.photoAppeared(firstPage[20], pixelWidth: 400)
        viewModel.photoAppeared(firstPage[14], pixelWidth: 400)
        #expect(loader.prefetches.last == firstPage[2..<14].map { photo in photo.imageRequest(pixelWidth: 400) })
    }

    @Test func cancellingClearsPrefetches() async {
        let viewModel = await loadedViewModel()
        viewModel.photoAppeared(firstPage[10], pixelWidth: 400)
        viewModel.cancel()
        #expect(loader.prefetches.last == [])
    }

    @Test func photoLookupFindsLoadedPhoto() async {
        let viewModel = await loadedViewModel()
        #expect(viewModel.photo(id: "first-3") == firstPage[3])
        #expect(viewModel.photo(id: "missing") == nil)
    }

    @Test func threeColumnsFillTheGridWidth() {
        #expect(makeViewModel().itemPixelWidth(gridWidth: 402, columnCount: 3, displayScale: 3) == 398)
    }

    @Test func twoColumnsGiveWiderItems() {
        #expect(makeViewModel().itemPixelWidth(gridWidth: 402, columnCount: 2, displayScale: 3) == 600)
    }

    @Test func zeroGridWidthStillGivesOnePixel() {
        #expect(makeViewModel().itemPixelWidth(gridWidth: 0, columnCount: 3, displayScale: 3) == 1)
    }

    private func makeViewModel(cache: (any FeedCaching)? = nil) -> PhotoFeedViewModel {
        PhotoFeedViewModel(
            query: nil,
            loadPage: { [service] page in try await service.editorialPhotos(page: page) },
            cache: cache,
            imageLoader: loader,
            now: { [now] in now }
        )
    }

    private func loadedViewModel() async -> PhotoFeedViewModel {
        await service.stub(.success(.mock(firstPage)))
        let viewModel = makeViewModel()
        await viewModel.load()
        return viewModel
    }

    private func failedNextPageViewModel() async -> PhotoFeedViewModel {
        let viewModel = await loadedViewModel()
        await service.stub(.failure(URLError(.notConnectedToInternet)))
        viewModel.photoAppeared(firstPage[29], pixelWidth: 400)
        await waitUntil { viewModel.state.failure != nil }
        return viewModel
    }

    private func settle() async {
        for _ in 0..<20 {
            await Task.yield()
        }
    }
}
