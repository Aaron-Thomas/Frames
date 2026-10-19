import Foundation
import FramesCore
import ImagePipeline

@MainActor
public final class GalleryCoordinator {
    let router = Router<GalleryCover>()
    let galleryViewModel: GalleryViewModel
    let imageLoader: any ImageLoading

    public init(service: any PhotoService,
                cache: any FeedCaching,
                imageLoader: any ImageLoading,
                clock: any Clock<Duration>,
                now: @escaping () -> Date) {
        self.imageLoader = imageLoader
        let makePhotoFeedViewModel = { (query: String?) in
            PhotoFeedViewModel(
                query: query,
                loadPage: { page in
                    guard let query else { return try await service.editorialPhotos(page: page) }
                    return try await service.searchPhotos(matching: query, page: page)
                },
                cache: query == nil ? cache : nil,
                imageLoader: imageLoader,
                now: now
            )
        }
        galleryViewModel = GalleryViewModel(
            editorialViewModel: makePhotoFeedViewModel(nil),
            clock: clock,
            makeSearchViewModel: makePhotoFeedViewModel
        )
    }

    func showPhoto(_ photo: Photo, thumbnail: ImageRequest) {
        router.present(GalleryCover(id: photo.id, thumbnail: thumbnail))
    }
}
