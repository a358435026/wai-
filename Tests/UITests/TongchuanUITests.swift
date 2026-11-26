import XCTest

final class TongchuanUITests: XCTestCase {
    func testLaunchAndCredentialSetup() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["scenePicker"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["mainAction"].exists)
        app.buttons["更多选项"].tap()
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
        app.buttons["scenePicker"].tap()
        XCTAssertTrue(app.buttons["faceToFaceScene"].waitForExistence(timeout: 5))
        app.buttons["完成"].tap()
        app.buttons["更多选项"].tap()
        app.buttons["连接诊断"].tap()
        XCTAssertTrue(app.staticTexts["音频已发送包数"].waitForExistence(timeout: 5))
        app.buttons["完成"].tap()
    }
    func testCaptionDisplayCanBeHiddenWithoutStoppingSession() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-captions"]
        app.launch()
        XCTAssertTrue(app.staticTexts["您好，我想了解这款电动车的续航和交货时间。"].waitForExistence(timeout: 10))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Bilingual conversation"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.buttons["隐藏字幕"].tap()
        XCTAssertTrue(app.buttons["显示字幕"].exists)
        XCTAssertFalse(app.staticTexts["您好，我想了解这款电动车的续航和交货时间。"].exists)
    }
}
