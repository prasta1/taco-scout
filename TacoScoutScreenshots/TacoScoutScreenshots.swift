import XCTest

final class TacoScoutScreenshots: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    @MainActor
    func testCaptureScreenshots() throws {
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments += ["-AppleLanguages", "(en)"]
        app.launchArguments += ["-AppleLocale", "en_US"]
        // Fixed location so screenshots show a populated map without depending on
        // the simulator's location/permission state.
        app.launchArguments += ["-uiTestLocation", "40.7580,-73.9855"]
        app.launch()

        // Dismiss onboarding if it appears — "Skip" ends the whole multi-page flow
        let skipButton = app.buttons["Skip"]
        if skipButton.waitForExistence(timeout: 4) {
            skipButton.tap()
        }

        // Allow location permission — the system alert belongs to SpringBoard,
        // not the app, so it must be tapped there.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allowButton = springboard.buttons["Allow While Using App"]
        if allowButton.waitForExistence(timeout: 8) {
            allowButton.tap()
        }

        // Wait for the location fix + nearby-taco search to resolve
        sleep(8)

        // 01 — Main map view
        snapshot("01-Map")

        // Pull the bottom sheet up to show the list
        let sheetHandle = app.otherElements.firstMatch
        let start = sheetHandle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
        let end = sheetHandle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.0))
        start.press(forDuration: 0.1, thenDragTo: end)
        sleep(1)

        // 02 — Taco list
        snapshot("02-TacoList")

        // Tap first taco in the list
        let firstCell = app.buttons.matching(identifier: "taco-row").firstMatch
        if firstCell.waitForExistence(timeout: 3) {
            firstCell.tap()
            sleep(2)
            // 03 — Taco detail
            snapshot("03-TacoDetail")
            app.swipeDown()
        }

        // 04 — Lucky Pick
        let luckyPickButton = app.buttons["lucky-pick-button"]
        if luckyPickButton.waitForExistence(timeout: 3) {
            luckyPickButton.tap()
            sleep(2)
            snapshot("04-LuckyPick")
            app.swipeDown()
        }

        // 05 — Filters
        let filterButton = app.buttons["filter-button"]
        if filterButton.waitForExistence(timeout: 3) {
            filterButton.tap()
            sleep(1)
            snapshot("05-Filters")
            app.buttons["Done"].firstMatch.tap()
        }
    }
}
