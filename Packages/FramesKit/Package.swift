// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FramesKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "FramesCore", targets: ["FramesCore"]),
        .library(name: "ImagePipeline", targets: ["ImagePipeline"]),
        .library(name: "GalleryFeature", targets: ["GalleryFeature"]),
        .library(name: "MockServices", targets: ["MockServices"])
    ],
    targets: [
        .target(name: "FramesCore"),
        .target(name: "ImagePipeline", dependencies: ["FramesCore"]),
        .target(name: "FramesCoreUI", dependencies: ["FramesCore", "ImagePipeline"]),
        .target(name: "GalleryFeature", dependencies: ["FramesCore", "ImagePipeline", "FramesCoreUI"]),
        .target(
            name: "MockServices",
            dependencies: ["FramesCore", "GalleryFeature"],
            resources: [.process("Resources")]
        ),
        .target(
            name: "TestHelpers",
            dependencies: ["FramesCore", "ImagePipeline", "GalleryFeature"],
            path: "Tests/TestHelpers"
        ),
        .testTarget(name: "FramesCoreTests", dependencies: ["FramesCore", "TestHelpers"]),
        .testTarget(name: "ImagePipelineTests", dependencies: ["FramesCore", "ImagePipeline", "TestHelpers"]),
        .testTarget(name: "GalleryFeatureTests", dependencies: ["FramesCore", "ImagePipeline", "GalleryFeature", "TestHelpers"]),
        .testTarget(name: "MockServicesTests", dependencies: ["FramesCore", "GalleryFeature", "MockServices", "TestHelpers"])
    ]
)
