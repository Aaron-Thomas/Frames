import SwiftUI
import FramesCore
import ImagePipeline

public struct RemoteImage: View {
    @Environment(\.imageLoader) private var imageLoader
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var loadedImage: UIImage?
    @State private var hasFailed = false
    private let request: ImageRequest
    private let placeholder: Color
    private let contentMode: ContentMode

    private var image: UIImage? {
        loadedImage ?? imageLoader?.cachedImage(for: request)
    }

    public init(request: ImageRequest, placeholder: Color, contentMode: ContentMode) {
        self.request = request
        self.placeholder = placeholder
        self.contentMode = contentMode
    }

    public var body: some View {
        placeholder
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                        .transition(.opacity)
                } else if hasFailed {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
            }
            .task(id: request) { await load() }
            .onDisappear { loadedImage = nil }
    }

    private func load() async {
        guard let imageLoader else { return }
        hasFailed = false
        do {
            let image = try await imageLoader.image(for: request)
            try Task.checkCancellation()
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { loadedImage = image }
        } catch where error.isCancellation {
            return
        } catch {
            hasFailed = true
        }
    }
}
