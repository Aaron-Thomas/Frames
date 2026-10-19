import Foundation
import Testing
@testable import GalleryFeature
import ImagePipeline
import TestHelpers

@MainActor
struct GalleryCoordinatorTests {
    private let service = StubPhotoService()

    @Test func showingPhotoPresentsViewer() {
        let coordinator = makeCoordinator()
        coordinator.showPhoto(.mock(id: "abc"), thumbnail: .mock())
        #expect(coordinator.router.presented == GalleryCover(id: "abc", thumbnail: .mock()))
    }

    @Test func editorialFeedUsesEditorialEndpoint() async {
        await service.stub(.success(.mock([])))
        await makeCoordinator().galleryViewModel.editorialViewModel.load()
        #expect(await service.invocations == [.editorial(page: 1)])
    }

    @Test func searchFeedUsesSearchEndpoint() async throws {
        await service.stub(.success(.mock([])))
        let galleryViewModel = makeCoordinator().galleryViewModel
        galleryViewModel.query = "cats"
        await galleryViewModel.searchQueryChanged()
        let searchViewModel = try #require(galleryViewModel.searchViewModel)
        await searchViewModel.load()
        #expect(await service.invocations == [.search(query: "cats", page: 1)])
    }

    private func makeCoordinator() -> GalleryCoordinator {
        GalleryCoordinator(
            service: service,
            cache: StubFeedCache(),
            imageLoader: StubImageLoader(),
            clock: RecordingClock(),
            now: Date.init
        )
    }
}
