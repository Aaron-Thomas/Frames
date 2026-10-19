import Foundation

public struct ImageRequest: Hashable, Sendable {
    let url: URL
    let targetPixelSize: Int

    var cacheKey: NSString {
        "\(targetPixelSize)@\(url.absoluteString)" as NSString
    }

    public init(url: URL, targetPixelSize: Int) {
        self.url = url
        self.targetPixelSize = targetPixelSize
    }
}
