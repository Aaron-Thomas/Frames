import SwiftUI
import ImagePipeline

struct GalleryView: View {
    @Bindable var viewModel: GalleryViewModel
    let namespace: Namespace.ID
    let showPhoto: (Photo, ImageRequest) -> Void

    var body: some View {
        ZStack {
            if let searchViewModel = viewModel.searchViewModel {
                PhotoFeedView(viewModel: searchViewModel, namespace: namespace, showPhoto: showPhoto)
                    .id(ObjectIdentifier(searchViewModel))
                    .transition(.opacity)
            } else {
                PhotoFeedView(viewModel: viewModel.editorialViewModel, namespace: namespace, showPhoto: showPhoto)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.searchViewModel.map(ObjectIdentifier.init))
        .navigationTitle("Frames")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $viewModel.query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search photos"
        )
        .task(id: viewModel.query) { await viewModel.searchQueryChanged() }
    }
}
