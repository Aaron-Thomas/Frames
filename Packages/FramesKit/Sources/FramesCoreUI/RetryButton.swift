import SwiftUI

public struct RetryButton: View {
    private let action: () -> Void

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        Button("Retry", action: action)
            .buttonStyle(.bordered)
    }
}
