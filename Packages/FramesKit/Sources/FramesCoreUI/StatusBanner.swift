import SwiftUI
import FramesCore

public struct StatusBanner: View {
    private let failure: LoadFailure
    private let shownSince: Date
    private let retry: () -> Void

    public init(failure: LoadFailure, shownSince: Date, retry: @escaping () -> Void) {
        self.failure = failure
        self.shownSince = shownSince
        self.retry = retry
    }

    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: failure.systemImage)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(failure.title)
                    .font(.subheadline.weight(.semibold))
                Text("Showing photos from \(shownSince, format: .dateTime.day().month().hour().minute())")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            RetryButton(action: retry)
        }
        .padding(12)
        .background(.regularMaterial, in: .rect(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}
