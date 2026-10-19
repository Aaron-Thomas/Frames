import UIKit

enum ImageDecoder {
    static func decode(_ data: Data, targetPixelSize: Int) -> UIImage? {
        let interval = ImagePipeline.signposter.beginInterval("Decode", id: ImagePipeline.signposter.makeSignpostID())
        defer { ImagePipeline.signposter.endInterval("Decode", interval) }
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { return nil }
        let maxPixelSize = maxPixelSize(width: width, height: height, targetPixelSize: targetPixelSize)
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options).map { cgImage in UIImage(cgImage: cgImage) }
    }

    static func maxPixelSize(width: Int, height: Int, targetPixelSize: Int) -> Int {
        let shorterSide = min(width, height)
        let longerSide = max(width, height)
        guard shorterSide > targetPixelSize else { return longerSide }
        return longerSide * targetPixelSize / shorterSide
    }
}
