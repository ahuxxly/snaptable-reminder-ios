import XCTest

final class AppStoreScreenshotUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments = ["-demoData", "-resetDemoData"]
        app.launch()
    }

    func testAppStoreScreenshots() throws {
        try assertNavigationTitle("Capture")
        captureScreenshot(named: "01-Capture")

        try selectTab("Records")
        XCTAssertTrue(app.staticTexts["Tuition Payment Notice"].waitForExistence(timeout: 5))
        captureScreenshot(named: "02-Records")

        try selectTab("Dashboard")
        XCTAssertTrue(app.staticTexts["Saved Records"].waitForExistence(timeout: 5))
        captureScreenshot(named: "03-Dashboard")

        try selectTab("Settings")
        XCTAssertTrue(app.staticTexts["Privacy"].waitForExistence(timeout: 5))
        captureScreenshot(named: "04-Settings")
    }

    private func selectTab(_ title: String) throws {
        let button = app.tabBars.buttons[title]
        XCTAssertTrue(button.waitForExistence(timeout: 5), "\(title) tab should exist")
        button.tap()
        try assertNavigationTitle(title)
    }

    private func assertNavigationTitle(_ title: String) throws {
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5), "\(title) screen should be visible")
    }

    private func captureScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
