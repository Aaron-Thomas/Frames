import Foundation
import Observation
import FramesCore
import ImagePipeline

@MainActor
@Observable
final class PhotoFeedViewModel {
    static let loadMoreThreshold = 12
    static let prefetchCount = 12
    static let savedPageCount = 5
    static let spacing: CGFloat = 2

    // Photos are kept apart from `state` so a page starting to load doesn't redraw the grid.
    private(set) var photos: [Photo] = []
    private(set) var state: LoadState<Paginator<Photo>> = .idle
    private var pageTask: Task<Void, Never>?
    private var lastAppearedIndex = 0
    /// Where the grid was scrolled to, so it can be restored after a search.
    var scrollAnchor: Photo.ID?
    let query: String?
    private let loadPage: @Sendable (Int) async throws -> PhotoPage
    private let cache: (any FeedCaching)?
    private let imageLoader: any ImageLoading
    private let now: () -> Date

    /// Saved photos are seeded at page 1, so any later page means the network has answered.
    var hasLoadedFromNetwork: Bool {
        (state.lastLoaded?.value.nextPage ?? 1) > 1
    }

    var isShowingSavedPhotos: Bool {
        !hasLoadedFromNetwork && !photos.isEmpty
    }

    private var isNearEnd: Bool {
        guard case .loaded(let loaded) = state, loaded.value.hasMore else { return false }
        return lastAppearedIndex >= photos.count - Self.loadMoreThreshold
    }

    init(query: String?,
         loadPage: @escaping @Sendable (Int) async throws -> PhotoPage,
         cache: (any FeedCaching)?,
         imageLoader: any ImageLoading,
         now: @escaping () -> Date) {
        self.query = query
        self.loadPage = loadPage
        self.cache = cache
        self.imageLoader = imageLoader
        self.now = now
    }

    func load() async {
        guard !hasLoadedFromNetwork, !state.isLoading, state.failure == nil else { return }
        if case .idle = state, let saved = await cache?.savedPhotos() {
            show(LoadedValue(value: Paginator(items: saved.value), loadedAt: saved.loadedAt))
        }
        await loadNextPage()
        if isNearEnd {
            startLoadingNextPage()
        }
    }

    /// The width an item is drawn at in pixels, so its image is fetched and decoded at the size shown.
    func itemPixelWidth(gridWidth: CGFloat, columnCount: Int, displayScale: CGFloat) -> Int {
        let itemWidth = (gridWidth - Self.spacing * CGFloat(columnCount - 1)) / CGFloat(columnCount)
        return max(1, Int((itemWidth * displayScale).rounded(.up)))
    }

    func photoAppeared(_ photo: Photo, pixelWidth: Int) {
        guard let index = state.lastLoaded?.value.index(of: photo.id) else { return }
        let isScrollingUp = index < lastAppearedIndex
        lastAppearedIndex = index
        let ahead = isScrollingUp
            ? max(0, index - Self.prefetchCount)..<index
            : index + 1..<min(photos.count, index + 1 + Self.prefetchCount)
        imageLoader.prefetch(photos[ahead].map { $0.imageRequest(pixelWidth: pixelWidth) })
        if isNearEnd {
            startLoadingNextPage()
        }
    }

    func retry() {
        startLoadingNextPage()
    }

    func photo(id: Photo.ID) -> Photo? {
        state.lastLoaded?.value.index(of: id).map { photos[$0] }
    }

    func cancel() {
        pageTask?.cancel()
        imageLoader.prefetch([])
    }

    private func startLoadingNextPage() {
        guard pageTask == nil else { return }
        pageTask = Task {
            await loadNextPage()
            pageTask = nil
            // A page of repeats adds no items, so no new item will appear to ask for the next one.
            if isNearEnd {
                startLoadingNextPage()
            }
        }
    }

    private func loadNextPage() async {
        guard !state.isLoading else { return }
        var paginator = hasLoadedFromNetwork ? state.lastLoaded?.value ?? Paginator() : Paginator()
        state.startLoading()
        do {
            let page = try await loadPage(paginator.nextPage)
            paginator.append(page.photos, hasMore: page.hasMore)
            let loaded = LoadedValue(value: paginator, loadedAt: now())
            show(loaded)
            if let cache, paginator.nextPage <= Self.savedPageCount + 1 {
                await cache.save(LoadedValue(value: paginator.items, loadedAt: loaded.loadedAt))
            }
        } catch where error.isCancellation {
            state.cancelLoading()
        } catch {
            state.fail(with: LoadFailure(error))
        }
    }

    private func show(_ loaded: LoadedValue<Paginator<Photo>>) {
        state = .loaded(loaded)
        photos = loaded.value.items
    }
}
