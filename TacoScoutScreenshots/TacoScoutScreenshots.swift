import XCTest

final class TacoScoutScreenshots: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        setupSnapshot(app)
        // Simulate San Antonio, TX — a city with great taco density
        app.launchArguments += ["-AppleLanguages", "(en)"]
        app.launchArguments += ["-AppleLocale", "en_US"]
        app.launch()
    }

    func testCaptureScreenshots() throws {
        // Dismiss onboarding if it appears
        let continueButton = app.buttons["Continue"]
        if continueButton.waitForExistence(timeout: 3) {
            continueButton.tap()
        }

        // Allow location permission
        let allowButton = app.buttons["Allow While Using App"]
        if allowButton.waitForExistence(timeout: 5) {
            allowButton.tap()
        }

        // Wait for map and taco list to load
        sleep(5)

        // 01 — Main map view
        snapshot("01-Map")

        // Pull the bottom sheet up to show the list
        let sheet = app.otherElements["taco-list-sheet"]
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
            app.buttons["Done"].tap()
        }

        // 04 — Lucky Pick
        let luckyPickButton = app.buttons["lucky-pick-button"]
        if luckyPickButton.waitForExistence(timeout: 3) {
            luckyPickButton.tap()
            sleep(2)
            snapshot("04-LuckyPick")
            app.buttons["Dismiss"].firstMatch.tap()
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
