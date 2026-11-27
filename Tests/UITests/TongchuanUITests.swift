import XCTest

final class TongchuanUITests: XCTestCase {
    private func openMore(_ app: XCUIApplication, destination: String) {
        app.buttons["moreOptions"].tap()
        if !app.buttons[destination].waitForExistence(timeout: 5) {
            app.buttons["moreOptions"].tap()
        }
        XCTAssertTrue(app.buttons[destination].waitForExistence(timeout: 5))
    }
    func testProviderSetupKeepsKeysSeparateAndShowsAutomaticSource() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-reset-languages"]
        app.launch()
        openMore(app, destination: "设置"); app.buttons["设置"].tap()
        app.buttons["阿里百炼"].tap()
        let host = app.textFields["bailianHostField"]
        XCTAssertTrue(host.waitForExistence(timeout: 5))
        host.tap()
        host.typeText("ws-ui-test.cn-beijing.maas.aliyuncs.com")
        let key = app.secureTextFields["apiKeyField"]
        key.tap(); key.typeText("sk-ui-test-not-a-real-credential")
        app.buttons["saveCredentials"].tap()
        let saved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: key)
        XCTAssertEqual(XCTWaiter.wait(for: [saved], timeout: 8), .completed, app.debugDescription)
        XCTAssertTrue(app.buttons["scenePicker"].label.contains("自动识别"))
        openMore(app, destination: "设置"); app.buttons["设置"].tap()
        XCTAssertTrue(app.staticTexts["已保存 API Key"].waitForExistence(timeout: 5))
        app.buttons["火山引擎"].tap()
        XCTAssertTrue(app.staticTexts["尚未配置 API Key"].waitForExistence(timeout: 5))
        app.buttons["阿里百炼"].tap()
        XCTAssertTrue(app.staticTexts["已保存 API Key"].waitForExistence(timeout: 5))
        let settings = XCTAttachment(screenshot: app.screenshot())
        settings.name = "Bailian settings with isolated synthetic test credential"; settings.lifetime = .keepAlways; add(settings)
        app.buttons["完成"].tap()
        app.buttons["scenePicker"].tap()
        XCTAssertTrue(app.staticTexts["自动识别（60语种）"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["sourceLanguagePicker"].exists)
        app.buttons["targetLanguagePicker"].tap()
        let search = app.searchFields.firstMatch; search.tap(); search.typeText("hi")
        app.buttons["language-hi"].tap()
        let languages = XCTAttachment(screenshot: app.screenshot())
        languages.name = "Bailian automatic source and Hindi spoken output"; languages.lifetime = .keepAlways; add(languages)
        app.buttons["完成"].tap()
        XCTAssertTrue(app.buttons["scenePicker"].label.contains("印地语"))
        XCTAssertFalse(app.staticTexts["outputModeHint"].exists)
    }
    func testSearchLanguageSwapAndTrueSubtitlesMode() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-reset-languages"]
        app.launch()
        app.buttons["scenePicker"].tap()
        app.buttons["targetLanguagePicker"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap(); search.typeText("es")
        app.buttons["language-es"].tap()
        XCTAssertTrue(app.buttons["swapLanguages"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["西班牙语（墨西哥）"].waitForExistence(timeout: 5))
        app.buttons["swapLanguages"].tap()
        XCTAssertTrue(app.staticTexts["中文（普通话）"].exists)
        app.buttons["swapLanguages"].tap()
        let mode = app.switches["subtitlesOnly"]
        XCTAssertEqual(mode.value as? String, "0")
        mode.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.5)).tap()
        XCTAssertTrue(NSPredicate(format: "value == %@", "1").evaluate(with: mode))
        let pair = XCTAttachment(screenshot: app.screenshot())
        pair.name = "Spanish language selection and subtitle service mode"
        pair.lifetime = .keepAlways; add(pair)
        app.buttons["完成"].tap()
        XCTAssertTrue(app.buttons["scenePicker"].label.contains("西班牙语"))
        XCTAssertTrue(app.staticTexts["outputModeHint"].waitForExistence(timeout: 5))
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
        openMore(app, destination: "连接诊断 / 测试收音")
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
        openMore(app, destination: "设置")
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
        openMore(app, destination: "连接诊断 / 测试收音")
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
