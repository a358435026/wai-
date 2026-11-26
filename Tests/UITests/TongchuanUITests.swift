import XCTest

final class TongchuanUITests: XCTestCase {
    func testSearchLanguageSwapAndTrueSubtitlesMode() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-reset-languages"]
        app.launchArguments.append("--ui-reset-languages")
        app.launch()
        app.buttons["scenePicker"].tap()
        app.buttons["targetLanguagePicker"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap(); search.typeText("西班牙")
        app.buttons["language-es"].tap()
        XCTAssertTrue(app.staticTexts["西班牙语（墨西哥）"].waitForExistence(timeout: 5))
        app.buttons["swapLanguages"].tap()
        XCTAssertTrue(app.staticTexts["中文（普通话）"].exists)
        app.buttons["swapLanguages"].tap()
        app.switches["subtitlesOnly"].tap()
        let pair = XCTAttachment(screenshot: app.screenshot())
        pair.name = "Spanish language selection and subtitle service mode"
        pair.lifetime = .keepAlways; add(pair)
        app.buttons["完成"].tap()
        XCTAssertTrue(app.buttons["scenePicker"].label.contains("西班牙语"))
        XCTAssertTrue(app.staticTexts["仅字幕：本次不生成译音"].exists)
    }
    func testSpeakingVisualizationAndOfflineMicrophoneEntry() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-speaking"]
        app.launchArguments.append("--ui-reset-languages")
        app.launch()
        XCTAssertTrue(app.buttons["voiceStatus"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["正在播报 · 点击打断"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Speaking visualization (presentation fixture)"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["moreOptions"].tap()
        app.buttons["连接诊断 / 测试收音"].tap()
        XCTAssertTrue(app.buttons["localMicTest"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["录音回调次数"].exists)
    }
    func testLaunchAndCredentialSetup() throws {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-reset-languages")
        app.launch()
        XCTAssertTrue(app.buttons["scenePicker"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["mainAction"].exists)
        app.buttons["moreOptions"].tap()
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
        app.buttons["moreOptions"].tap()
        app.buttons["连接诊断 / 测试收音"].tap()
        XCTAssertTrue(app.staticTexts["音频已发送包数"].waitForExistence(timeout: 5))
        app.buttons["完成"].tap()
    }
    func testCaptionDisplayCanBeHiddenWithoutStoppingSession() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-captions"]
        app.launchArguments.append("--ui-reset-languages")
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
