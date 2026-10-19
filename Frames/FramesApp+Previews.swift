import SwiftUI
import GalleryFeature
import MockServices

#Preview("recorded") {
    if let coordinator = FramesApp.makeCoordinator(scenario: .recorded, accessKey: nil) {
        GalleryCoordinatorView(coordinator: coordinator)
    }
}

#Preview("offline") {
    if let coordinator = FramesApp.makeCoordinator(scenario: .offline, accessKey: nil) {
        GalleryCoordinatorView(coordinator: coordinator)
    }
}

#Preview("recorded, accessibility size") {
    if let coordinator = FramesApp.makeCoordinator(scenario: .recorded, accessKey: nil) {
        GalleryCoordinatorView(coordinator: coordinator)
            .dynamicTypeSize(.accessibility2)
    }
}
