import XCTest

final class TongchuanUITests: XCTestCase {
    func testLaunchAndCredentialSetup() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.navigationBars["随声同传"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["mainAction"].exists)
        app.buttons["设置"].tap()
        XCTAssertTrue(app.secureTextFields["apiKeyField"].waitForExistence(timeout: 5))
        // No API Key or live billable request is used by this smoke test.
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Settings"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.buttons["完成"].tap()
        let home = XCTAttachment(screenshot: app.screenshot())
        home.name = "Home"
        home.lifetime = .keepAlways
        add(home)
    }
}
