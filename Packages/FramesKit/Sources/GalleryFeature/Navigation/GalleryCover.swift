import ImagePipeline

/// The full-screen viewer: the photo to show and the grid's image to show while a larger one loads.
struct GalleryCover: Hashable, Identifiable {
    let id: Photo.ID
    let thumbnail: ImageRequest
}
