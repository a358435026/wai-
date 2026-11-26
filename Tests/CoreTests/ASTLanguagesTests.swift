import XCTest
@testable import TongchuanCore

final class ASTLanguagesTests: XCTestCase {
    func testPublishedCatalogHas48Languages9InputDialectsAnd16DefaultSpeechTargets() {
        XCTAssertEqual(ASTLanguages.spoken.count, 48)
        XCTAssertEqual(ASTLanguages.dialects.count, 9)
        XCTAssertEqual(ASTLanguages.sources.count, 58) // Includes Chinese/English mixed detection.
        XCTAssertEqual(Set(ASTLanguages.sources.map(\.id)).count, 58)
        XCTAssertEqual(ASTLanguages.spoken.filter(\.defaultSpeech).count, 16)
        for code in ["ja", "es", "pt", "fr", "de", "id", "vi", "th", "ar"] {
            XCTAssertTrue(ASTLanguages.target(code)?.defaultSpeech == true)
        }
    }
    func testSupportedPairsDoNotOfferForeignToForeignOrSameLanguage() {
        XCTAssertNil(ASTLanguages.validationError(source: "zh", target: "es"))
        XCTAssertNil(ASTLanguages.validationError(source: "es", target: "zh"))
        XCTAssertNil(ASTLanguages.validationError(source: "en", target: "ja"))
        XCTAssertNotNil(ASTLanguages.validationError(source: "ja", target: "es"))
        XCTAssertNotNil(ASTLanguages.validationError(source: "en", target: "en"))
        XCTAssertNotNil(ASTLanguages.validationError(source: "unknown", target: "zh"))
        XCTAssertEqual(Set(ASTLanguages.targets(for: "ja").map(\.id)), ["zh", "en"])
    }
    func testDialectsAndMixedDetectionOnlyTranslateIntoChineseOrEnglish() {
        for code in ["yue-CN", "sh-CN", "sc", "auto"] {
            XCTAssertNil(ASTLanguages.validationError(source: code, target: "zh"))
            XCTAssertNil(ASTLanguages.validationError(source: code, target: "en"))
            XCTAssertNotNil(ASTLanguages.validationError(source: code, target: "ja"))
        }
        XCTAssertNotNil(ASTLanguages.validationError(source: "zh", target: "yue-CN"))
    }
    func testOutputCapabilityAndExplicitSubtitlesChooseRealServiceMode() {
        XCTAssertEqual(ASTLanguages.mode(target: "es", subtitlesOnly: false), .speechToSpeech)
        XCTAssertEqual(ASTLanguages.mode(target: "es", subtitlesOnly: true), .subtitles)
        XCTAssertEqual(ASTLanguages.mode(target: "hi", subtitlesOnly: false), .subtitles)
        XCTAssertEqual(ASTLanguages.mode(target: "unknown", subtitlesOnly: false), .subtitles)
    }
    func testTextOnlyRequestUsesS2TAndOmitsTargetAudio() throws {
        let config = ASTConfiguration(source: "zh", target: "hi", mode: .subtitles)
        let fields = try ProtoWire.decode(ASTRequest.start(sessionID: "text-only", configuration: config))
        XCTAssertNil(fields.first { $0.number == 5 })
        let parameters = try ProtoWire.decode(XCTUnwrap(fields.first { $0.number == 6 }?.bytes))
        func text(_ number: Int) -> String? {
            parameters.first { $0.number == number }?.bytes.flatMap { String(data: $0, encoding: .utf8) }
        }
        XCTAssertEqual(text(1), "s2t")
        XCTAssertEqual(text(2), "zh")
        XCTAssertEqual(text(3), "hi")
    }
    func testSpanishSpeechUsesServiceCodeRatherThanLocalizedLabel() throws {
        let config = ASTConfiguration(source: "zh", target: "es")
        let fields = try ProtoWire.decode(ASTRequest.start(sessionID: "spanish", configuration: config))
        XCTAssertNotNil(fields.first { $0.number == 5 })
        let parameters = try ProtoWire.decode(XCTUnwrap(fields.first { $0.number == 6 }?.bytes))
        XCTAssertEqual(parameters.first { $0.number == 3 }?.bytes, Data("es".utf8))
        XCTAssertEqual(parameters.first { $0.number == 1 }?.bytes, Data("s2s".utf8))
    }
}
