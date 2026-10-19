import SwiftUI
import FramesCore
import GalleryFeature
import ImagePipeline
import MockServices

@main
struct FramesApp: App {
    private let coordinator = Self.makeCoordinator(
        scenario: Scenario(launchArgument: UserDefaults.standard.string(forKey: "scenario")),
        accessKey: Bundle.main.object(forInfoDictionaryKey: "UnsplashAccessKey") as? String
    )

    var body: some Scene {
        WindowGroup {
            rootView
        }
    }
    
    @ViewBuilder
    private var rootView: some View {
        if let coordinator {
            GalleryCoordinatorView(coordinator: coordinator)
        } else {
            ContentUnavailableView(
                "Add an Unsplash access key",
                systemImage: "key",
                description: Text("Put your key in Config/Secrets.xcconfig as the README explains, then run again.")
            )
        }
    }

    static func makeCoordinator(scenario: Scenario?, accessKey: String?) -> GalleryCoordinator? {
        let clock = ContinuousClock()
        let service: any PhotoService
        let cache: any FeedCaching
        if let scenario {
            service = MockPhotoService(scenario: scenario, clock: clock)
            cache = scenario.makeFeedCache()
        } else if let accessKey, !accessKey.isEmpty {
            service = UnsplashPhotoService(accessKey: accessKey, client: URLSession.shared)
            cache = FileFeedCache(fileURL: URL.cachesDirectory.appending(path: "editorial-feed.json"))
        } else {
            return nil
        }
        return GalleryCoordinator(
            service: service,
            cache: cache,
            imageLoader: makeImagePipeline(scenario: scenario),
            clock: clock,
            now: Date.init
        )
    }

    private static func makeImagePipeline(scenario: Scenario?) -> ImagePipeline {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(
            memoryCapacity: 0,
            diskCapacity: 300 * 1024 * 1024,
            directory: URL.cachesDirectory.appending(path: "Images")
        )
        let session = URLSession(configuration: configuration)
        return ImagePipeline(
            client: scenario?.imageClient(wrapping: session) ?? session,
            memoryLimit: Int(min(ProcessInfo.processInfo.physicalMemory / 20, 150 * 1024 * 1024)),
            memoryWarnings: .default
        )
    }
}
