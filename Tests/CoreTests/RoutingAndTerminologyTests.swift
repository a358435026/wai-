import XCTest
@testable import TongchuanCore

final class RoutingAndTerminologyTests: XCTestCase {
    func testMultilingualDialogueRoutesChineseToReplyAndForeignSpeechToMandarin() {
        XCTAssertEqual(ConversationTurnRouting.destination(text: "这款车多少钱？", detected: "zh-Hans", reply: "es"), "es")
        XCTAssertEqual(ConversationTurnRouting.destination(text: "交货期？", detected: nil, reply: "en"), "en")
        for (text, detected) in [("How much is it?", "en"), ("¿Cuánto cuesta?", "es"), ("Сколько стоит?", "ru"), ("これはいくら？", "ja")] {
            XCTAssertEqual(ConversationTurnRouting.destination(text: text, detected: detected, reply: "en"), "zh")
        }
    }
    func testHTTPAuthenticationIsNotReportedAsBalance() {
        let auth = ConnectionFailure(provider: .volcengine, status: 401).localizedDescription
        XCTAssertTrue(auth.contains("鉴权失败")); XCTAssertTrue(auth.contains("401"))
        XCTAssertFalse(auth.contains("余额不足"))
        XCTAssertTrue(ConnectionFailure(provider: .volcengine, code: -1011).localizedDescription.contains("不能判定欠费"))
    }
    func testFallbackPreservesTargetAndSpeechModeAndNeverPingsPong() throws {
        let config = ASTConfiguration(source: "zh", target: "pt")
        let backup = try XCTUnwrap(FailoverPolicy.configuration(for: .bailian, current: config, automaticSource: "zh"))
        XCTAssertEqual(backup.target, "pt"); XCTAssertEqual(backup.mode, .speechToSpeech)
        XCTAssertEqual(FailoverPolicy.destination(current: .volcengine, tried: [.volcengine], configured: [.volcengine, .bailian]), .bailian)
        XCTAssertNil(FailoverPolicy.destination(current: .bailian, tried: [.volcengine, .bailian], configured: [.volcengine, .bailian]))
        XCTAssertNil(FailoverPolicy.destination(current: .volcengine, tried: [.volcengine], configured: [.volcengine]))
    }
    func testAutomaticSourceRequiresExplicitCompatibleBackupSource() {
        let english = ASTConfiguration(source: "bailian-auto", target: "en")
        XCTAssertEqual(FailoverPolicy.configuration(for: .volcengine, current: english, automaticSource: "zh")?.source, "zh")
        let hindi = ASTConfiguration(source: "bailian-auto", target: "hi")
        XCTAssertNil(FailoverPolicy.configuration(for: .volcengine, current: hindi, automaticSource: "zh"))
        let invalidPair = ASTConfiguration(source: "bailian-auto", target: "es")
        XCTAssertNil(FailoverPolicy.configuration(for: .volcengine, current: invalidPair, automaticSource: "ja"))
        XCTAssertNil(FailoverPolicy.configuration(for: .bailian, current: ASTConfiguration(source: "zhen", target: "zhen"), automaticSource: "zh"))
    }
    func testHealthDoesNotSwitchOnSilencePartialsOrEarlierTranslation() {
        let start = Date(timeIntervalSince1970: 100)
        var health = TranslationHealth()
        XCTAssertFalse(health.stalled(at: start.addingTimeInterval(60), suspended: false))
        health.sourceBegan()
        XCTAssertFalse(health.stalled(at: start.addingTimeInterval(60), suspended: false))
        health.translated(at: start); health.sourceCompleted(at: start.addingTimeInterval(1))
        XCTAssertFalse(health.stalled(at: start.addingTimeInterval(60), suspended: false))
    }
    func testHealthOnlyTimesCompletedSourceAndClearsAfterTranslation() {
        let start = Date(timeIntervalSince1970: 100)
        var health = TranslationHealth(); health.sourceBegan(); health.sourceCompleted(at: start)
        XCTAssertFalse(health.stalled(at: start.addingTimeInterval(9), suspended: false))
        XCTAssertTrue(health.stalled(at: start.addingTimeInterval(10), suspended: false))
        XCTAssertFalse(health.stalled(at: start.addingTimeInterval(20), suspended: true))
        health.translated(at: start.addingTimeInterval(2))
        XCTAssertEqual(health.lastLatency, 2)
        XCTAssertFalse(health.stalled(at: start.addingTimeInterval(60), suspended: false))
    }
    func testTerminologyDirectionsAndCustomOverrides() throws {
        XCTAssertEqual(TradeTerminology.preset(source: "zh", target: "en")["额定功率"], "rated power")
        XCTAssertEqual(TradeTerminology.preset(source: "en", target: "zh")["rated power"], "额定功率")
        XCTAssertNotNil(TradeTerminology.preset(source: "bailian-auto", target: "pt")["额定功率"])
        XCTAssertTrue(TradeTerminology.preset(source: "zh", target: "ja").isEmpty)
        let value = try TradeTerminology.combined(source: "zh", target: "en", enabled: true,
            customSource: "zh", customTarget: "en", custom: "额定功率\tnominal power")
        XCTAssertEqual(value["额定功率"], "nominal power")
        let portuguese = try TradeTerminology.combined(source: "zh", target: "pt", enabled: true,
            customSource: "zh", customTarget: "en", custom: "额定功率\tnominal power")
        XCTAssertNotEqual(portuguese["额定功率"], "nominal power")
        XCTAssertTrue(try TradeTerminology.combined(source: "zh", target: "en", enabled: false,
            customSource: "zh", customTarget: "en", custom: "bad-input").isEmpty)
    }
    func testCSVTSVJSONImportAndBounds() throws {
        XCTAssertEqual(try TradeTerminology.parse("source,target\n\"产品,型号\",\"model \"\"A\"\"\""), ["产品,型号":"model \"A\""])
        XCTAssertEqual(try TradeTerminology.parse("交货期\tlead time"), ["交货期":"lead time"])
        XCTAssertEqual(try TradeTerminology.parse(#"{"交货期":"lead time"}"#), ["交货期":"lead time"])
        for bad in ["word,", "a,b\na,c", "\"unclosed,value", String(repeating: "x", count: 32_001), (0..<101).map { "a\($0),b" }.joined(separator: "\n")] {
            XCTAssertThrowsError(try TradeTerminology.parse(bad))
        }
    }
    func testGeneralTradeTermsAndAutomaticSourceWithCustomTermsAtLimit() throws {
        let forward = TradeTerminology.preset(source: "zh", target: "en")
        XCTAssertEqual(forward["信用证"], "letter of credit")
        XCTAssertEqual(forward["商品编码"], "HS code")
        XCTAssertEqual(forward["船上交货"], "FOB")
        let automatic = TradeTerminology.preset(source: "bailian-auto", target: "en")
        XCTAssertLessThanOrEqual(automatic.count, 100)
        XCTAssertEqual(automatic["船上交货"], "FOB")
        XCTAssertEqual(automatic["bicicleta eléctrica"], "electric bicycle")
        let custom = (0..<100).map { "词\($0)\tterm \($0)" }.joined(separator: "\n")
        let combined = try TradeTerminology.combined(source: "bailian-auto", target: "en", enabled: true,
            customSource: "zh", customTarget: "en", custom: custom)
        XCTAssertEqual(combined, try TradeTerminology.parse(custom))
    }
    func testBothProvidersReceiveTheDocumentedGlossarySchema() throws {
        let config = ASTConfiguration(glossary: ["交货期":"lead time"])
        let fixtureURL = try XCTUnwrap(Bundle.module.url(forResource: "terms-start", withExtension: "hex", subdirectory: "Fixtures"))
        let hex = try String(contentsOf: fixtureURL).trimmingCharacters(in: .whitespacesAndNewlines)
        let chars = Array(hex)
        let official = Data(stride(from: 0, to: chars.count, by: 2).map { UInt8(String(chars[$0...($0 + 1)]), radix: 16)! })
        XCTAssertEqual(ASTRequest.start(sessionID: "terms", configuration: config), official)
        let fields = try ProtoWire.decode(official)
        let params = try ProtoWire.decode(XCTUnwrap(fields.first { $0.number == 6 }?.bytes))
        let corpus = try ProtoWire.decode(XCTUnwrap(params.first { $0.number == 100 }?.bytes))
        let entry = try ProtoWire.decode(XCTUnwrap(corpus.first { $0.number == 10 }?.bytes))
        XCTAssertEqual(String(data: try XCTUnwrap(entry.first { $0.number == 1 }?.bytes), encoding: .utf8), "交货期")
        XCTAssertEqual(String(data: try XCTUnwrap(entry.first { $0.number == 2 }?.bytes), encoding: .utf8), "lead time")
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: BailianWire.start(config)) as? [String: Any])
        let session = try XCTUnwrap(object["session"] as? [String: Any])
        let translation = try XCTUnwrap(session["translation"] as? [String: Any])
        let dictionary = try XCTUnwrap(translation["corpus"] as? [String: Any])
        XCTAssertEqual(dictionary["phrases"] as? [String: String], config.glossary)
    }
}
