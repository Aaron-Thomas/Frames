import SwiftUI
import FramesCore

public struct PageFooter: View {
    private let isLoading: Bool
    private let failure: LoadFailure?
    private let retry: () -> Void

    public init(isLoading: Bool, failure: LoadFailure?, retry: @escaping () -> Void) {
        self.isLoading = isLoading
        self.failure = failure
        self.retry = retry
    }

    public var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let failure {
                VStack(spacing: 8) {
                    Label(failure.title, systemImage: failure.systemImage)
                        .font(.subheadline)
                    RetryButton(action: retry)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 72)
    }
}
