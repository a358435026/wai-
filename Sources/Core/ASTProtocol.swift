import Foundation

// Field numbers come from the official AST .proto files in Protocol/.
// This small wire codec avoids a generated-code/runtime dependency in the app.
public enum ProtoError: Error, Equatable { case truncated, invalidVarint, unsupportedWire(Int), invalidUTF8 }

public struct ProtoField {
    public let number: Int
    public let integer: UInt64?
    public let bytes: Data?
}

public enum ProtoWire {
    public static func varint(_ value: UInt64) -> Data {
        var value = value
        var result = Data()
        while value >= 128 { result.append(UInt8(value & 127) | 128); value >>= 7 }
        result.append(UInt8(value))
        return result
    }
    public static func int(_ field: Int, _ value: UInt64) -> Data {
        varint(UInt64(field << 3)) + varint(value)
    }
    public static func bytes(_ field: Int, _ value: Data) -> Data {
        varint(UInt64((field << 3) | 2)) + varint(UInt64(value.count)) + value
    }
    public static func string(_ field: Int, _ value: String) -> Data {
        bytes(field, Data(value.utf8))
    }
    public static func decode(_ data: Data) throws -> [ProtoField] {
        let input = [UInt8](data)
        var cursor = 0
        func readVarint() throws -> UInt64 {
            var value: UInt64 = 0
            for index in 0..<10 {
                guard cursor < input.count else { throw ProtoError.truncated }
                let byte = input[cursor]; cursor += 1
                if index == 9 && byte > 1 { throw ProtoError.invalidVarint }
                value |= UInt64(byte & 127) << (index * 7)
                if byte & 128 == 0 { return value }
            }
            throw ProtoError.invalidVarint
        }
        var result: [ProtoField] = []
        while cursor < input.count {
            let key = try readVarint()
            let field = Int(key >> 3), wire = Int(key & 7)
            guard field > 0 && field <= 0x1fff_ffff else { throw ProtoError.invalidVarint }
            switch wire {
            case 0:
                result.append(ProtoField(number: field, integer: try readVarint(), bytes: nil))
            case 2:
                let length = try readVarint()
                guard length <= UInt64(input.count - cursor) else { throw ProtoError.truncated }
                let end = cursor + Int(length)
                result.append(ProtoField(number: field, integer: nil, bytes: Data(input[cursor..<end])))
                cursor = end
            case 1, 5:
                let length = wire == 1 ? 8 : 4
                guard length <= input.count - cursor else { throw ProtoError.truncated }
                cursor += length // Unknown fixed-width fields are forward compatible.
            default: throw ProtoError.unsupportedWire(wire)
            }
        }
        return result
    }
}

public enum ASTMode: String, Equatable, Sendable {
    case speechToSpeech = "s2s"
    case subtitles = "s2t"
}

public struct ASTConfiguration: Equatable, Sendable {
    public var source: String
    public var target: String
    public var speaker: String
    public var ttsResource: String
    public var glossary: [String: String]
    public var mode: ASTMode
    public init(source: String = "zh", target: String = "en", speaker: String = "", ttsResource: String = "",
                mode: ASTMode = .speechToSpeech, glossary: [String: String] = [:]) {
        self.source = source; self.target = target; self.speaker = speaker; self.ttsResource = ttsResource
        self.mode = mode; self.glossary = glossary
    }
}

public enum ASTRequest {
    public static func start(sessionID: String, configuration: ASTConfiguration) -> Data {
        var source = ProtoWire.string(4, "wav") + ProtoWire.string(5, "raw")
        source += ProtoWire.int(7, 16000) + ProtoWire.int(8, 16) + ProtoWire.int(9, 1)
        let target = ProtoWire.string(4, "pcm") + ProtoWire.int(7, 16000)
        var params = ProtoWire.string(1, configuration.mode.rawValue) + ProtoWire.string(2, configuration.source)
        params += ProtoWire.string(3, configuration.target)
        if !configuration.speaker.isEmpty { params += ProtoWire.string(4, configuration.speaker) }
        if !configuration.ttsResource.isEmpty { params += ProtoWire.string(8, configuration.ttsResource) }
        if !configuration.glossary.isEmpty {
            // Official ReqParams.corpus=100; Corpus.glossary_list=10 (not request field3).
            let entries = configuration.glossary.sorted { $0.key < $1.key }.reduce(into: Data()) { data, term in
                data += ProtoWire.bytes(10, ProtoWire.string(1, term.key) + ProtoWire.string(2, term.value))
            }
            params += ProtoWire.bytes(100, entries)
        }
        var result = meta(sessionID) + ProtoWire.int(2, 100) + ProtoWire.bytes(4, source)
        if configuration.mode == .speechToSpeech { result += ProtoWire.bytes(5, target) }
        return result + ProtoWire.bytes(6, params)
    }
    public static func audio(sessionID: String, pcm: Data) -> Data {
        meta(sessionID) + ProtoWire.int(2, 200) + ProtoWire.bytes(4, ProtoWire.bytes(14, pcm))
    }
    public static func finish(sessionID: String) -> Data { meta(sessionID) + ProtoWire.int(2, 102) }
    private static func meta(_ id: String) -> Data { ProtoWire.bytes(1, ProtoWire.string(6, id)) }
}

public struct ASTResponse: Equatable, Sendable {
    public let event: Int
    public let text: String
    public let audio: Data
    public let statusCode: Int
    public let message: String
    public let sessionID: String
    public var captionID: String = ""
    public var final: Bool = false
    public var sourceLanguage: String?
    public init(event: Int, text: String = "", audio: Data = Data(), captionID: String = "",
                final: Bool = false, sourceLanguage: String? = nil) {
        self.event = event; self.text = text; self.audio = audio
        self.captionID = captionID; self.final = final
        self.sourceLanguage = sourceLanguage
        statusCode = 0; message = ""; sessionID = ""
    }
    public init(data: Data) throws {
        let fields = try ProtoWire.decode(data)
        func bytes(_ number: Int) -> Data { fields.last { $0.number == number }?.bytes ?? Data() }
        func string(_ value: Data) throws -> String {
            guard let text = String(data: value, encoding: .utf8) else { throw ProtoError.invalidUTF8 }
            return text
        }
        guard let eventValue = Int(exactly: fields.last { $0.number == 2 }?.integer ?? 0) else {
            throw ProtoError.invalidVarint
        }
        event = eventValue
        text = try string(bytes(4)); audio = bytes(3)
        let meta = try ProtoWire.decode(bytes(1))
        statusCode = Int(Int32(truncatingIfNeeded: meta.last { $0.number == 3 }?.integer ?? 0))
        message = try string(meta.last { $0.number == 4 }?.bytes ?? Data())
        sessionID = try string(meta.last { $0.number == 1 }?.bytes ?? Data())
    }
}
