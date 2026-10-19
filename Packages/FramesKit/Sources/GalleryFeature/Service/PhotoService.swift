public protocol PhotoService: Sendable {
    func editorialPhotos(page: Int) async throws -> PhotoPage
    func searchPhotos(matching query: String, page: Int) async throws -> PhotoPage
}
