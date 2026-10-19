import XCTest

final class FramesUITests: XCTestCase {
    private let photoItems = NSPredicate(format: "identifier BEGINSWITH 'photo-'")
    private let repeatedPhotoItems = NSPredicate(format: "identifier CONTAINS '-repeat'")

    @MainActor
    func testBrowsingOpeningAndSearching() {
        let app = XCUIApplication()
        app.launchArguments = ["-scenario", "recorded"]
        app.launch()

        let firstPhoto = app.buttons.matching(photoItems).firstMatch
        XCTAssertTrue(firstPhoto.waitForExistence(timeout: 10))

        var swipes = 0
        while !app.buttons.matching(repeatedPhotoItems).firstMatch.exists, swipes < 30 {
            app.swipeUp(velocity: .fast)
            swipes += 1
        }
        let repeatedPhoto = app.buttons.matching(repeatedPhotoItems).firstMatch
        XCTAssertTrue(repeatedPhoto.exists, "Scrolling never reached a fourth page")

        app.buttons.matching(repeatedPhotoItems).firstMatch.tap()
        let close = app.buttons["close-photo"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 5))

        let search = app.searchFields.firstMatch
        search.tap()
        search.typeText("nature")
        XCTAssertTrue(app.buttons.matching(photoItems).firstMatch.waitForExistence(timeout: 10))
    }
}
