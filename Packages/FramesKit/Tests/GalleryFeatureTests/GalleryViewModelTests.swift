import Foundation
import Testing
@testable import GalleryFeature
import TestHelpers

@MainActor
struct GalleryViewModelTests {
    private let clock = RecordingClock()
    private let searchViewModelFactory = SearchViewModelFactory()

    @Test func searchWaitsForDebounce() async {
        let viewModel = makeViewModel()
        viewModel.query = " cats "
        await viewModel.searchQueryChanged()
        #expect(await clock.sleeps == [.milliseconds(400)])
        #expect(viewModel.searchViewModel?.query == "cats")
    }

    @Test func emptyQueryShowsEditorialFeed() async {
        let viewModel = makeViewModel()
        viewModel.query = "cats"
        await viewModel.searchQueryChanged()
        viewModel.query = ""
        await viewModel.searchQueryChanged()
        #expect(viewModel.searchViewModel == nil)
        #expect(await clock.sleeps.count == 1)
    }

    @Test func unchangedQueryKeepsSearch() async {
        let viewModel = makeViewModel()
        viewModel.query = "cats"
        await viewModel.searchQueryChanged()
        let firstSearchViewModel = viewModel.searchViewModel
        viewModel.query = "cats "
        await viewModel.searchQueryChanged()
        #expect(viewModel.searchViewModel === firstSearchViewModel)
        #expect(searchViewModelFactory.queries == ["cats"])
    }

    @Test func cancelledDebounceStartsNoSearch() async {
        let viewModel = makeViewModel()
        viewModel.query = "cats"
        let typing = Task { await viewModel.searchQueryChanged() }
        typing.cancel()
        await typing.value
        #expect(viewModel.searchViewModel == nil)
        #expect(searchViewModelFactory.queries.isEmpty)
    }

    @Test func photoLookupFallsBackToEditorial() async {
        let photo = Photo.mock(id: "editorial")
        let editorialViewModel = makePhotoFeedViewModel(query: nil, photos: [photo])
        await editorialViewModel.load()
        let viewModel = GalleryViewModel(
            editorialViewModel: editorialViewModel,
            clock: clock,
            makeSearchViewModel: searchViewModelFactory.make
        )
        #expect(viewModel.photo(id: "editorial") == photo)
    }

    private func makeViewModel() -> GalleryViewModel {
        GalleryViewModel(
            editorialViewModel: makePhotoFeedViewModel(query: nil),
            clock: clock,
            makeSearchViewModel: searchViewModelFactory.make
        )
    }
}

@MainActor
private final class SearchViewModelFactory {
    private(set) var queries: [String] = []

    func make(query: String) -> PhotoFeedViewModel {
        queries.append(query)
        return makePhotoFeedViewModel(query: query)
    }
}

@MainActor
private func makePhotoFeedViewModel(query: String?, photos: [Photo] = []) -> PhotoFeedViewModel {
    PhotoFeedViewModel(
        query: query,
        loadPage: { _ in .mock(photos) },
        cache: nil,
        imageLoader: StubImageLoader(),
        now: Date.init
    )
}
