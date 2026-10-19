import SwiftUI
import FramesCore
import FramesCoreUI

public struct GalleryCoordinatorView: View {
    @Bindable private var router: Router<GalleryCover>
    @Namespace private var namespace
    private let coordinator: GalleryCoordinator

    public init(coordinator: GalleryCoordinator) {
        self.coordinator = coordinator
        router = coordinator.router
    }

    public var body: some View {
        NavigationStack {
            GalleryView(viewModel: coordinator.galleryViewModel, namespace: namespace, showPhoto: coordinator.showPhoto)
        }
        .photoPresentation(item: $router.presented, in: namespace, content: viewer)
        .environment(\.imageLoader, coordinator.imageLoader)
    }

    @ViewBuilder
    private func viewer(for cover: GalleryCover) -> some View {
        if let photo = coordinator.galleryViewModel.photo(id: cover.id) {
            PhotoViewer(photo: photo, thumbnail: cover.thumbnail, close: router.dismiss)
        } else {
            ContentUnavailableView {
                Label("Photo not available", systemImage: "photo")
            } actions: {
                Button("Close", action: router.dismiss)
            }
        }
    }
}
