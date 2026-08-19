import XCTest

final class HSclubsAppUITests: XCTestCase {
    @MainActor
    func testLaunchesDirectory() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-empty", "--ui-testing-reset"]
        app.launch()

        XCTAssertTrue(app.staticTexts["No schools yet"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSearchesByHostAndResetsResults() {
        let app = launchSampleDirectory()
        let search = app.searchFields["Search by school or host"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))

        search.tap()
        search.typeText("clubs.beta.example")

        XCTAssertTrue(app.buttons["school-card-beta"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["school-card-alpha"].exists)

        app.buttons["Clear text"].tap()
        XCTAssertTrue(app.buttons["school-card-alpha"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSelectsSchoolAndShowsSwitcher() {
        let app = launchSampleDirectory()
        let school = app.buttons["school-card-alpha"]
        XCTAssertTrue(school.waitForExistence(timeout: 5))
        school.tap()

        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 5))
        let switcher = app.buttons["school-site-back"]
        XCTAssertTrue(switcher.waitForExistence(timeout: 5))
        switcher.tap()
        let action = app.buttons["switch-school-action"]
        XCTAssertTrue(action.waitForExistence(timeout: 5))
        action.tap()
        XCTAssertTrue(app.searchFields["Search by school or host"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testReopensLastSchoolOnNextLaunch() {
        let app = launchSampleDirectory()
        let school = app.buttons["school-card-alpha"]
        XCTAssertTrue(school.waitForExistence(timeout: 5))
        school.tap()
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 5))

        app.terminate()
        app.launchArguments = ["--ui-testing-sample"]
        app.launch()

        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 10))
        XCTAssertFalse(app.searchFields["Search by school or host"].exists)
    }

    @MainActor
    func testDraggingSwitcherMovesEdgesWithoutOpeningPanel() {
        let app = launchSampleDirectory()
        let school = app.buttons["school-card-alpha"]
        XCTAssertTrue(school.waitForExistence(timeout: 5))
        school.tap()

        let switcher = app.buttons["school-site-back"]
        XCTAssertTrue(switcher.waitForExistence(timeout: 5))
        let start = switcher.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let destination = app.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.55))
        start.press(forDuration: 0.2, thenDragTo: destination)

        XCTAssertLessThan(switcher.frame.midX, app.frame.midX)
        XCTAssertFalse(app.buttons["switch-school-action"].exists)

        switcher.tap()
        XCTAssertTrue(app.buttons["switch-school-action"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testIncompatibleSchoolIsVisibleButNotEnterable() {
        let app = launchSampleDirectory()
        let incompatible = app.buttons["school-card-gamma"]
        XCTAssertTrue(incompatible.waitForExistence(timeout: 5))
        // Visible, but the guiding page marked it incompatible: the row is disabled and tapping
        // it must not open a site.
        XCTAssertFalse(incompatible.isEnabled)
        incompatible.tap()
        XCTAssertFalse(app.webViews.firstMatch.waitForExistence(timeout: 2))
    }

    @MainActor
    private func launchSampleDirectory() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-sample", "--ui-testing-reset"]
        app.launch()
        return app
    }
}
