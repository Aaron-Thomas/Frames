import Foundation
import Testing
import FramesCore
@testable import GalleryFeature
@testable import MockServices
import TestHelpers

struct MockServicesTests {
    @Test func recordedPagesRepeatAsNewPhotos() throws {
        let firstPass = try MockData.editorialPage(1).photos
        let secondPass = try MockData.editorialPage(MockData.recordedPageCount + 1).photos
        #expect(secondPass.count == firstPass.count)
        #expect(Set(firstPass.map(\.id)).isDisjoint(with: secondPass.map(\.id)))
        let firstImages = Set(firstPass.map { $0.imageRequest(pixelWidth: 400) })
        #expect(firstImages.isDisjoint(with: secondPass.map { $0.imageRequest(pixelWidth: 400) }))
    }

    @Test func searchStopsAfterLastPage() throws {
        #expect(try MockData.searchPage(MockData.searchPageCount - 1).hasMore)
        #expect(try MockData.searchPage(MockData.searchPageCount).hasMore == false)
    }

    @Test func offlineScenarioFailsWithNoConnection() async {
        let service = MockPhotoService(scenario: .offline, clock: RecordingClock())
        await #expect(throws: URLError(.notConnectedToInternet)) { try await service.editorialPhotos(page: 1) }
    }

    @Test func rateLimitedScenarioFailsAfterSecondPage() async throws {
        let service = MockPhotoService(scenario: .rateLimited, clock: RecordingClock())
        _ = try await service.editorialPhotos(page: 2)
        await #expect(throws: HTTPStatusError(statusCode: 403, isRateLimited: true)) {
            try await service.editorialPhotos(page: 3)
        }
    }

    @Test func slowScenarioWaitsTwoSeconds() async throws {
        let clock = RecordingClock()
        _ = try await MockPhotoService(scenario: .slow, clock: clock).searchPhotos(matching: "cats", page: 1)
        #expect(await clock.sleeps == [.seconds(2)])
    }

    @Test func offlineWithCacheStartsWithRecordedPhotos() async throws {
        let saved = try #require(await Scenario.offlineWithCache.makeFeedCache().savedPhotos())
        #expect(saved.value == (try MockData.recordedPhotos()))
        #expect(saved.loadedAt < .now)
    }

    @Test(arguments: [Scenario.recorded, .slow, .offline, .rateLimited])
    func otherScenariosStartWithNothingSaved(scenario: Scenario) async {
        #expect(await scenario.makeFeedCache().savedPhotos() == nil)
    }

    @Test func scenarioCacheKeepsWhatIsSaved() async {
        let cache = Scenario.recorded.makeFeedCache()
        let photos = LoadedValue(value: Photo.mocks(2), loadedAt: Date(timeIntervalSince1970: 1))
        await cache.save(photos)
        #expect(await cache.savedPhotos() == photos)
    }

    @Test func launchArgumentSelectsScenario() {
        #expect(Scenario(launchArgument: "slow") == .slow)
        #expect(Scenario(launchArgument: "unknown") == nil)
        #expect(Scenario(launchArgument: nil) == nil)
    }

    @Test(arguments: [(Scenario.offline, URLRequest.CachePolicy.returnCacheDataDontLoad),
                      (.offlineWithCache, .returnCacheDataDontLoad),
                      (.recorded, .returnCacheDataElseLoad)])
    func offlineScenariosOnlyUseCachedImages(scenario: Scenario, expectedPolicy: URLRequest.CachePolicy) async throws {
        let client = StubHTTPClient()
        await client.stub(data: Data())
        let request = URLRequest(url: URL(filePath: "/image.jpg"), cachePolicy: .returnCacheDataElseLoad)
        _ = try await scenario.imageClient(wrapping: client).send(request)
        #expect(await client.requests.first?.cachePolicy == expectedPolicy)
    }
}
