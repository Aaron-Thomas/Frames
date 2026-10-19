import Foundation
import Observation

@MainActor
@Observable
final class GalleryViewModel {
    static let debounce = Duration.milliseconds(400)

    var query = ""
    private(set) var searchViewModel: PhotoFeedViewModel?
    let editorialViewModel: PhotoFeedViewModel
    private let clock: any Clock<Duration>
    private let makeSearchViewModel: (String) -> PhotoFeedViewModel

    init(editorialViewModel: PhotoFeedViewModel,
         clock: any Clock<Duration>,
         makeSearchViewModel: @escaping (String) -> PhotoFeedViewModel) {
        self.editorialViewModel = editorialViewModel
        self.clock = clock
        self.makeSearchViewModel = makeSearchViewModel
    }

    func searchQueryChanged() async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery != searchViewModel?.query else { return }
        guard !trimmedQuery.isEmpty else { return replaceSearchViewModel(with: nil) }
        try? await clock.sleep(for: Self.debounce)
        guard !Task.isCancelled else { return }
        replaceSearchViewModel(with: makeSearchViewModel(trimmedQuery))
    }

    func photo(id: Photo.ID) -> Photo? {
        searchViewModel?.photo(id: id) ?? editorialViewModel.photo(id: id)
    }

    private func replaceSearchViewModel(with viewModel: PhotoFeedViewModel?) {
        searchViewModel?.cancel()
        searchViewModel = viewModel
    }
}
