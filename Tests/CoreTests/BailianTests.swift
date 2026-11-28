import XCTest
@testable import TongchuanCore

final class BailianTests: XCTestCase {
    func testCatalogAndPerProviderAudioRate() {
        XCTAssertEqual(BailianLanguages.targets.count, 60)
        XCTAssertEqual(BailianLanguages.targets.filter(\.defaultSpeech).count, 29)
        XCTAssertEqual(Set(BailianLanguages.targets.map(\.id)).count, 60)
        XCTAssertTrue(BailianLanguages.target("hi")!.defaultSpeech)
        XCTAssertFalse(BailianLanguages.target("yue")!.defaultSpeech)
        XCTAssertEqual(TranslationProvider.bailian.outputRate, 24000)
        XCTAssertEqual(TranslationProvider.volcengine.outputRate, 16000)
    }
    func testHostValidationRejectsKeysAndForeignEndpoints() throws {
        XCTAssertEqual(try BailianWire.normalizedHost(" https://ws-test.cn-beijing.maas.aliyuncs.com/path "), "ws-test.cn-beijing.maas.aliyuncs.com")
        for value in ["sk-test-not-a-key", "1247753508747675", "example.com", "workspaceid.cn-beijing.maas.aliyuncs.com", "a.cn-beijing.maas.aliyuncs.com.evil.test"] {
            XCTAssertThrowsError(try BailianWire.endpoint(host:value))
        }
    }
    func testWireModesAndPCMFrames() throws {
        func session(_ target: String, _ mode: ASTMode) throws -> [String: Any] {
            let data = try BailianWire.start(ASTConfiguration(source:"bailian-auto", target:target, mode:mode))
            return try XCTUnwrap((JSONSerialization.jsonObject(with:data) as? [String:Any])?["session"] as? [String:Any])
        }
        XCTAssertEqual(try session("en", .speechToSpeech)["output_modalities"] as? [String], ["text","audio"])
        XCTAssertEqual(try session("en", .subtitles)["output_modalities"] as? [String], ["text"])
        XCTAssertEqual(try session("yue", .speechToSpeech)["output_modalities"] as? [String], ["text"])
        let frame = try XCTUnwrap(JSONSerialization.jsonObject(with:BailianWire.audio(Data([0,255,1,128]))) as? [String:Any])
        XCTAssertEqual(Data(base64Encoded:frame["audio"] as! String), Data([0,255,1,128]))
        XCTAssertEqual((try JSONSerialization.jsonObject(with:BailianWire.finish) as? [String:String])?["type"], "session.finish")
    }
    func testHandshakeDoesNotBecomeLiveUntilConfigurationAcknowledged() throws {
        var decoder = BailianDecoder()
        XCTAssertTrue(try decoder.decode(Data(#"{"type":"session.created"}"#.utf8)).isEmpty)
        XCTAssertEqual(try decoder.decode(Data(#"{"type":"session.updated"}"#.utf8)).first?.event, 150)
        XCTAssertEqual(try decoder.decode(Data(#"{"type":"session.finished"}"#.utf8)).first?.event, 152)
    }
    func testFinalCaptionReplacesIncrementalTextAndInterleavedItemsStayDistinct() throws {
        var decoder = BailianDecoder(); var lane = CaptionLane()
        let events = [
            #"{"type":"conversation.item.input_audio_transcription.delta","item_id":"a","delta":"你"}"#,
            #"{"type":"conversation.item.input_audio_transcription.delta","item_id":"b","delta":"再见"}"#,
            #"{"type":"conversation.item.input_audio_transcription.delta","item_id":"a","delta":"好"}"#,
            #"{"type":"conversation.item.input_audio_transcription.completed","item_id":"a","transcript":"你好。","language":"zh"}"#]
        for event in events {
            let response = try XCTUnwrap(decoder.decode(Data(event.utf8)).first)
            XCTAssertEqual(response.sourceLanguage, response.final ? "zh" : nil)
            lane.set(id:response.captionID, text:response.text, final:response.final)
        }
        XCTAssertEqual(lane.captions.map(\.text), ["你好。","再见"])
        XCTAssertTrue(lane.captions[0].final)
        XCTAssertFalse(lane.captions[1].final)
    }
    func testSubtitleOnlyAndSpeechTranscriptEvents() throws {
        for kind in ["response.text", "response.audio_transcript"] {
            var decoder = BailianDecoder()
            _ = try decoder.decode(JSONSerialization.data(withJSONObject:["type":kind+".delta", "item_id":"t", "delta":"Hell"]))
            let response = try XCTUnwrap(decoder.decode(JSONSerialization.data(withJSONObject:["type":kind+".done", "item_id":"t", "text":"Hello", "transcript":"Hello"])).first)
            XCTAssertEqual(response.event, 661); XCTAssertEqual(response.text, "Hello"); XCTAssertTrue(response.final)
        }
    }
    func testAudioAndServiceFailure() throws {
        var decoder = BailianDecoder()
        let response = try XCTUnwrap(decoder.decode(Data(#"{"type":"response.audio.delta","delta":"AAD/fw=="}"#.utf8)).first)
        XCTAssertEqual(response.audio, Data([0,0,255,127]))
        XCTAssertThrowsError(try decoder.decode(Data(#"{"type":"response.audio.delta","delta":"bad!"}"#.utf8)))
        XCTAssertThrowsError(try decoder.decode(Data(#"{"type":"error","error":{"code":"Forbidden","message":"model access denied"}}"#.utf8)))
    }
    func testRemoteCaptionHistoryRemainsBounded() {
        var lane = CaptionLane()
        for index in 0..<150 { lane.set(id:String(index), text:String(index), final:true) }
        XCTAssertEqual(lane.captions.count,100)
        XCTAssertEqual(lane.captions.first?.text,"50")
        lane.set(id:"149", text:"corrected", final:true)
        XCTAssertEqual(lane.captions.count,100); XCTAssertEqual(lane.captions.last?.text,"corrected")
    }
    func testFailedResponseDoesNotLookLikeSuccessfulTranslation() throws {
        var decoder = BailianDecoder()
        for status in ["failed", "incomplete"] {
            let message = try JSONSerialization.data(withJSONObject:["type":"response.done", "response":["status":status]])
            XCTAssertThrowsError(try decoder.decode(message))
        }
        XCTAssertTrue(try decoder.decode(Data(#"{"type":"response.done","response":{"status":"completed"}}"#.utf8)).isEmpty)
    }
}
