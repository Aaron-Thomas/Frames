import OSLog
import XCTest

/// The scroll behind the README's results: down past photo 450, then back to the top.
/// The Frames scheme skips this test. `scripts/profile.py` runs it through the FramesProfile scheme.
final class ScrollProfileTests: XCTestCase {
    private let signposter = OSSignposter(subsystem: "FramesUITests", category: .pointsOfInterest)
    private let photoItems = NSPredicate(format: "identifier BEGINSWITH 'photo-'")

    /// The test marks where scrolling starts, turns and ends, so the script can read each phase of a trace.
    @MainActor
    func testScrollingPastPhoto450AndBack() {
        let app = XCUIApplication()
        app.launchArguments = ["-scenario", "recorded"]
        app.launch()
        let firstPhoto = app.buttons.matching(photoItems).firstMatch
        XCTAssertTrue(firstPhoto.waitForExistence(timeout: 10))
        let topPhoto = app.buttons[firstPhoto.identifier]
        // Photos 451 to 540 are the sixth pass through the three recorded pages.
        let photo451 = app.buttons.matching(NSPredicate(format: "identifier ENDSWITH '-repeat5'")).firstMatch

        signposter.emitEvent("Scrolling down")
        flick(until: photo451) { app.swipeUp(velocity: .fast) }
        XCTAssertTrue(photo451.exists, "Scrolling never passed photo 450")

        signposter.emitEvent("Scrolling up")
        flick(until: topPhoto) { app.swipeDown(velocity: .fast) }
        XCTAssertTrue(topPhoto.exists, "Scrolling never returned to the top")
        signposter.emitEvent("Back at the top")
    }

    @MainActor
    private func flick(until element: XCUIElement, _ flick: () -> Void) {
        var flicks = 0
        while !element.exists, flicks < 150 {
            flick()
            flicks += 1
        }
    }
}
