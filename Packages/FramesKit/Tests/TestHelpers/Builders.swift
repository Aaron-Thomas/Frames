import Foundation
import UIKit
@testable import GalleryFeature
import ImagePipeline

extension Photo {
    public static func mock(id: String = "photo",
                            altDescription: String? = "a photo",
                            description: String? = nil,
                            color: String? = "#336699") -> Photo {
        Photo(
            id: id,
            description: description,
            altDescription: altDescription,
            width: 3000,
            height: 2000,
            color: color,
            urls: URLs(
                thumb: URL(filePath: "/\(id)/thumb.jpg"),
                small: URL(filePath: "/\(id)/small.jpg"),
                regular: URL(filePath: "/\(id)/regular.jpg")
            ),
            user: User(name: "Photographer", profileURL: URL(filePath: "/photographer"))
        )
    }

    public static func mocks(_ count: Int, prefix: String = "photo") -> [Photo] {
        (0..<count).map { index in .mock(id: "\(prefix)-\(index)") }
    }
}

extension PhotoPage {
    public static func mock(_ photos: [Photo], hasMore: Bool = true) -> PhotoPage {
        PhotoPage(photos: photos, hasMore: hasMore)
    }
}

extension ImageRequest {
    public static func mock(_ name: String = "image", targetPixelSize: Int = 400) -> ImageRequest {
        ImageRequest(url: URL(filePath: "/\(name).jpg"), targetPixelSize: targetPixelSize)
    }
}

extension UIImage {
    public static func mock(width: Int, height: Int) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }
}

extension URL {
    public static func uniqueTemporaryFile() -> URL {
        URL.temporaryDirectory.appending(path: "\(UUID().uuidString).json")
    }
}

extension Data {
    public static func mockJPEG(width: Int, height: Int) -> Data {
        UIImage.mock(width: width, height: height).jpegData(compressionQuality: 0.8) ?? Data()
    }
}
