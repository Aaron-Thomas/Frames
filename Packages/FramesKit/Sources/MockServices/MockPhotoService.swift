import GalleryFeature

public struct MockPhotoService: PhotoService {
    private let scenario: Scenario
    private let clock: any Clock<Duration>

    public init(scenario: Scenario, clock: any Clock<Duration>) {
        self.scenario = scenario
        self.clock = clock
    }

    public func editorialPhotos(page: Int) async throws -> PhotoPage {
        try await respond(toPage: page)
        return try MockData.editorialPage(page)
    }

    public func searchPhotos(matching query: String, page: Int) async throws -> PhotoPage {
        try await respond(toPage: page)
        return try MockData.searchPage(page)
    }

    private func respond(toPage page: Int) async throws {
        try await clock.sleep(for: scenario.latency)
        if let error = scenario.error(forPage: page) {
            throw error
        }
    }
}
