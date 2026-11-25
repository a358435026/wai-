import XCTest
@testable import TongchuanCore

final class ASTProtocolTests: XCTestCase {
    private func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "hex", subdirectory: "Fixtures"))
        let hex = try String(contentsOf: url).trimmingCharacters(in: .whitespacesAndNewlines)
        let chars = Array(hex)
        XCTAssertEqual(chars.count % 2, 0)
        return try Data(stride(from: 0, to: chars.count, by: 2).map {
            try XCTUnwrap(UInt8(String(chars[$0...($0 + 1)]), radix: 16))
        })
    }
    func testStartMatchesOfficialPythonProtobuf() throws {
        XCTAssertEqual(ASTRequest.start(sessionID: "interop-session", configuration: ASTConfiguration()),
                       try fixture("start"))
    }
    func testAudioMatchesOfficialPythonProtobuf() throws {
        XCTAssertEqual(ASTRequest.audio(sessionID: "interop-session", pcm: Data([0, 0, 255, 127, 0, 128])),
                       try fixture("audio"))
    }
    func testFinishMatchesOfficialPythonProtobuf() throws {
        XCTAssertEqual(ASTRequest.finish(sessionID: "interop-session"), try fixture("finish"))
    }
    func testDecodeOfficialResponseAndUnknownFields() throws {
        var bytes = try fixture("response")
        bytes += ProtoWire.int(1000, 98765)
        bytes += Data([0x9d, 0x06, 1, 2, 3, 4]) // unknown field 99, fixed32
        let response = try ASTResponse(data: bytes)
        XCTAssertEqual(response.event, 654)
        XCTAssertEqual(response.text, "Hello, 你好。")
        XCTAssertEqual(response.sessionID, "interop-session")
        XCTAssertEqual(response.statusCode, 20000000)
        XCTAssertEqual(response.audio, Data([0, 0, 255, 127, 0, 128]))
    }
    func testRejectMalformedRemoteFrames() {
        let malformed: [[UInt8]] = [[0x22, 0xff, 0x7f], [0x80], [0], [0x0b],
                                   Array(repeating: 0xff, count: 11)]
        for bytes in malformed {
            XCTAssertThrowsError(try ProtoWire.decode(Data(bytes)))
        }
    }
    func testDecodeServiceFailure() throws {
        let response = try ASTResponse(data: fixture("failure"))
        XCTAssertEqual(response.event, 153)
        XCTAssertEqual(response.statusCode, 11200)
        XCTAssertEqual(response.message, "Permission denied")
    }
    func testFramerPreservesSamplesAcrossArbitraryTapBoundaries() {
        var framer = PCMFramer()
        let input = Data((0..<9814).map { UInt8($0 % 251) })
        var frames = [Data]()
        var cursor = 0
        for size in [514, 200, 4096, 76, 4928] {
            frames += framer.append(Data(input[cursor..<(cursor + size)]))
            cursor += size
        }
        XCTAssertTrue(frames.allSatisfy { $0.count == 2560 })
        if let tail = framer.finish() { frames.append(tail) }
        XCTAssertEqual(frames.reduce(Data(), +), input)
        XCTAssertNil(framer.finish())
    }
    func testCaptionSentencesAppendFragmentsAndSealIndependently() {
        var lane = CaptionLane()
        lane.begin(); lane.append("Hello"); lane.append(", world."); lane.end()
        lane.begin(); lane.append("Next sentence.")
        XCTAssertEqual(lane.captions.map(\.text), ["Hello, world.", "Next sentence."])
        XCTAssertTrue(lane.captions[0].final)
        XCTAssertFalse(lane.captions[1].final)
    }
}
