import SwiftUI

extension LinearGradient {
    /// Fades from clear to dark at the bottom, so white caption text stays readable over any photo.
    public static var captionBackground: LinearGradient {
        LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
    }
}
