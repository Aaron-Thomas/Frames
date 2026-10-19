import SwiftUI
import FramesCoreUI

struct PhotoItem: View, Equatable {
    let photo: Photo
    let pixelWidth: Int

    var body: some View {
        let caption = photo.caption
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                RemoteImage(
                    request: photo.imageRequest(pixelWidth: pixelWidth),
                    placeholder: photo.placeholderColor,
                    contentMode: .fill
                )
            }
            .overlay(alignment: .bottomLeading) { captionLabel(caption) }
            .clipped()
            .contentShape(.rect)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(caption)
            .accessibilityAddTraits(.isImage)
    }

    private func captionLabel(_ caption: String) -> some View {
        Text(caption)
            .font(.caption2)
            .foregroundStyle(.white)
            .lineLimit(2)
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient.captionBackground)
    }
}
