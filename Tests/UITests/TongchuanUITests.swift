import XCTest

final class TongchuanUITests: XCTestCase {
    func testLaunchAndCredentialSetup() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.navigationBars["����ͬ��"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["mainAction"].exists)
        app.buttons["����"].tap()
        XCTAssertTrue(app.secureTextFields["apiKeyField"].waitForExistence(timeout: 5))
        // No API Key or live billable request is used by this smoke test.
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Settings"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.buttons["���"].tap()
        let home = XCTAttachment(screenshot: app.screenshot())
        home.name = "Home"
        home.lifetime = .keepAlways
        add(home)
    }
}
