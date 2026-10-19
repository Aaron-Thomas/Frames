import SwiftUI
import FramesCoreUI
import ImagePipeline

struct PhotoViewer: View {
    @State private var showsDetails = true
    let photo: Photo
    let thumbnail: ImageRequest
    let close: () -> Void

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            image
        }
        .overlay(alignment: .bottom) {
            if showsDetails {
                details
            }
        }
        .overlay(alignment: .topTrailing) {
            if showsDetails {
                closeButton
            }
        }
        .contentShape(.rect)
        .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { showsDetails.toggle() } }
        .statusBarHidden()
        .accessibilityAction(.escape, close)
    }

    private var image: some View {
        ZStack {
            RemoteImage(request: thumbnail, placeholder: photo.placeholderColor, contentMode: .fit)
            RemoteImage(request: photo.fullScreenImageRequest(), placeholder: .clear, contentMode: .fit)
        }
        .pinchToZoom()
        .aspectRatio(photo.aspectRatio, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(photo.caption)
        .accessibilityAddTraits(.isImage)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(photo.caption)
                .font(.headline)
            if let user = photo.user {
                Text(user.attribution)
                    .font(.footnote)
                    .tint(.white)
            }
        }
        .foregroundStyle(.white)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            LinearGradient.captionBackground
                .ignoresSafeArea()
        }
        .transition(.opacity)
    }

    private var closeButton: some View {
        Button(action: close) {
            Image(systemName: "xmark")
                .font(.body.weight(.semibold))
                .padding(12)
                .background(.ultraThinMaterial, in: .circle)
        }
        .foregroundStyle(.white)
        .padding()
        .accessibilityLabel("Close")
        .accessibilityIdentifier("close-photo")
        .transition(.opacity)
    }
}

private extension Photo.User {
    var attribution: AttributedString {
        var photographer = AttributedString(name)
        photographer.link = profileURL
        photographer.underlineStyle = .single
        var unsplash = AttributedString("Unsplash")
        unsplash.link = URL(string: "https://unsplash.com")?.appending(queryItems: Photo.referralQueryItems)
        unsplash.underlineStyle = .single
        return AttributedString("Photo by ") + photographer + AttributedString(" on ") + unsplash
    }
}
