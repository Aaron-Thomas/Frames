import SwiftUI
import FramesCore
import FramesCoreUI
import ImagePipeline

struct PhotoFeedView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.displayScale) private var displayScale
    @Bindable var viewModel: PhotoFeedViewModel
    let namespace: Namespace.ID
    let showPhoto: (Photo, ImageRequest) -> Void

    private var columns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 2 : 3
        return Array(repeating: GridItem(.flexible(), spacing: PhotoFeedViewModel.spacing), count: count)
    }

    var body: some View {
        GeometryReader { geometry in
            let pixelWidth = viewModel.itemPixelWidth(
                gridWidth: geometry.size.width,
                columnCount: columns.count,
                displayScale: displayScale
            )
            ScrollViewReader { scrollProxy in
                ScrollView {
                    LazyVGrid(columns: columns, spacing: PhotoFeedViewModel.spacing) {
                        ForEach(viewModel.photos) { photo in
                            item(for: photo, pixelWidth: pixelWidth)
                        }
                    }
                    .scrollTargetLayout()
                    FeedFooter(viewModel: viewModel)
                }
                .scrollPosition(id: $viewModel.scrollAnchor)
                .task {
                    // Restoring before the lazy grid's first layout leaves it unrendered below the anchor.
                    await Task.yield()
                    if let anchor = viewModel.scrollAnchor {
                        scrollProxy.scrollTo(anchor, anchor: .top)
                    }
                    await viewModel.load()
                }
            }
        }
        .overlay { FeedPlaceholder(viewModel: viewModel, columns: columns) }
        .safeAreaInset(edge: .top) { SavedPhotosBanner(viewModel: viewModel) }
    }

    private func item(for photo: Photo, pixelWidth: Int) -> some View {
        Button {
            showPhoto(photo, photo.imageRequest(pixelWidth: pixelWidth))
        } label: {
            PhotoItem(photo: photo, pixelWidth: pixelWidth)
                .equatable()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("photo-\(photo.id)")
        .photoTransitionSource(id: photo.id, in: namespace)
        .onAppear { viewModel.photoAppeared(photo, pixelWidth: pixelWidth) }
    }
}

private struct FeedFooter: View {
    let viewModel: PhotoFeedViewModel

    var body: some View {
        if viewModel.hasLoadedFromNetwork {
            PageFooter(isLoading: viewModel.state.isLoading, failure: viewModel.state.failure, retry: viewModel.retry)
        }
    }
}

private struct SavedPhotosBanner: View {
    let viewModel: PhotoFeedViewModel

    var body: some View {
        if viewModel.isShowingSavedPhotos, let failure = viewModel.state.failure, let savedAt = viewModel.state.lastLoaded?.loadedAt {
            StatusBanner(failure: failure, shownSince: savedAt, retry: viewModel.retry)
        }
    }
}

private struct FeedPlaceholder: View {
    let viewModel: PhotoFeedViewModel
    let columns: [GridItem]

    var body: some View {
        if viewModel.photos.isEmpty {
            switch viewModel.state {
            case .idle, .loading:
                skeleton
            case .failed(let failure, _):
                ContentUnavailableView {
                    Label(failure.title, systemImage: failure.systemImage)
                } description: {
                    Text(failure.message)
                } actions: {
                    RetryButton(action: viewModel.retry)
                }
            case .loaded:
                if let query = viewModel.query {
                    ContentUnavailableView.search(text: query)
                } else {
                    ContentUnavailableView("No photos yet", systemImage: "photo.on.rectangle")
                }
            }
        }
    }

    private var skeleton: some View {
        LazyVGrid(columns: columns, spacing: PhotoFeedViewModel.spacing) {
            ForEach(0..<18, id: \.self) { _ in
                Color(.secondarySystemFill)
                    .aspectRatio(1, contentMode: .fit)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading photos")
    }
}

private extension LoadFailure {
    var message: LocalizedStringKey {
        switch self {
        case .offline: "Photos will load when you're back online."
        case .rateLimited: "A demo key allows 50 requests an hour. Try again later."
        case .unauthorised: "Check UNSPLASH_ACCESS_KEY in Config/Secrets.xcconfig."
        case .unavailable: "Unsplash couldn't be reached. Try again."
        }
    }
}
