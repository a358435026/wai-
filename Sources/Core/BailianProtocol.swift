import Foundation

public enum TranslationProvider: String, CaseIterable, Identifiable, Sendable {
    case volcengine, bailian
    public var id: String { rawValue }
    public var title: String { self == .bailian ? "阿里百炼" : "火山引擎" }
    public var outputRate: Double { self == .bailian ? 24000 : 16000 }
}

public struct BailianError: LocalizedError {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}

public enum BailianLanguages {
    public static let automatic = ASTLanguage("bailian-auto", "自动识别（60语种）", short: "自动识别", speech: false)
    private static let audioCodes = Set("zh en ar de fr es pt id it ko ru th vi ja tr hi ms nl ur nb sv da he fi pl is cs fil fa".split(separator: " ").map(String.init))
    public static let targets: [ASTLanguage] = {
        let codes = "zh en ar de fr es pt id it ko ru th vi ja tr hi ms nl ur nb sv da he fi pl is cs fil fa yue el af ast be bg bn bs ca ceb et gl gu hr hu jv kk kn ky lv mk ml mr pa ro sk sl sw tg az uk".split(separator: " ").map(String.init)
        let names = ["nb":"挪威语", "he":"希伯来语", "yue":"粤语", "af":"南非荷兰语", "ast":"阿斯图里亚斯语", "be":"白俄罗斯语", "bs":"波斯尼亚语", "ceb":"宿务语", "gl":"加利西亚语", "gu":"古吉拉特语", "hr":"克罗地亚语", "kn":"卡纳达语", "ky":"柯尔克孜语", "mk":"马其顿语", "ml":"马拉雅拉姆语", "mr":"马拉地语", "sl":"斯洛文尼亚语", "tg":"塔吉克语"]
        return codes.map { code in
            ASTLanguage(code, ASTLanguages.target(code)?.shortName ?? names[code] ?? code, speech: audioCodes.contains(code))
        }
    }()
    public static func target(_ code: String) -> ASTLanguage? { targets.first { $0.id == code } }
}

public enum BailianWire {
    public static let model = "qwen3.8-livetranslate-flash-realtime"
    public static func normalizedHost(_ value: String) throws -> String {
        var host = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if host.contains("://") { host = URLComponents(string: host)?.host ?? "" }
        while host.hasSuffix("/") { host.removeLast() }
        let pattern = "^[a-z0-9-]+\\.(cn-beijing|ap-southeast-1)\\.maas\\.aliyuncs\\.com$"
        guard host.range(of: pattern, options: .regularExpression) != nil,
              !host.hasPrefix("workspaceid.") else {
            throw BailianError("请填写业务空间的 API Host，例如 ws-xxx.cn-beijing.maas.aliyuncs.com。此处不能填写 Key 或账号ID。")
        }
        return host
    }
    public static func endpoint(host: String) throws -> URL {
        let host = try normalizedHost(host)
        return URL(string: "wss://\(host)/api-ws/v1/realtime?model=\(model)")!
    }
    public static func start(_ configuration: ASTConfiguration) throws -> Data {
        guard let language = BailianLanguages.target(configuration.target) else { throw BailianError("百炼不支持所选目标语言。") }
        let speech = configuration.mode == .speechToSpeech && language.defaultSpeech
        let input: [String: Any] = ["format":["type":"pcm", "sample_rate":16000] as [String:Any],
                                    "turn_detection":["type":"speaker_detection", "threshold":0.5] as [String:Any]]
        var translation: [String: Any] = ["language": configuration.target]
        if !configuration.glossary.isEmpty { translation["corpus"] = ["phrases": configuration.glossary] }
        let session: [String: Any] = [
            "input_modalities":["audio"], "output_modalities": speech ? ["text", "audio"] : ["text"],
            "audio":["input":input, "output":["voice":"Tina"]] as [String:Any],
            "enable_voice_clone":false, "translation":translation
        ]
        return try JSONSerialization.data(withJSONObject: ["type":"session.update", "session":session])
    }
    public static func audio(_ pcm: Data) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["type":"input_audio_buffer.append", "audio":pcm.base64EncodedString()])
    }
    public static let finish = Data(#"{"type":"session.finish"}"#.utf8)
}

public struct BailianDecoder {
    private var text: [String: String] = [:]
    private var order: [String] = []
    public init() {}
    public mutating func decode(_ data: Data) throws -> [ASTResponse] {
        guard let event = try JSONSerialization.jsonObject(with: data) as? [String: Any], let kind = event["type"] as? String else { throw BailianError("百炼返回了无法识别的事件。") }
        if kind == "error" || kind == "conversation.item.input_audio_transcription.failed" {
            let error = event["error"] as? [String: Any] ?? [:]
            throw BailianError("百炼服务错误 \(error["code"] ?? "unknown")：\(error["message"] ?? "请检查权限、余额、地域和业务空间。")")
        }
        if let response = event["response"] as? [String:Any],
           let status = response["status"] as? String, ["failed", "incomplete"].contains(status) {
            throw BailianError("百炼本句译文未完成（\(status)）。已停止本次连接，请检查服务状态或稍后重试。")
        }
        switch kind {
        case "session.updated": return [ASTResponse(event:150)]
        case "session.finished": return [ASTResponse(event:152)]
        case "response.created": return [ASTResponse(event:350)]
        case "response.audio.delta":
            guard let value = event["delta"] as? String, let audio = Data(base64Encoded:value) else { throw BailianError("百炼译音分片格式错误。") }
            return [ASTResponse(event:352, audio:audio)]
        default: break
        }
        let source = kind.hasPrefix("conversation.item.input_audio_transcription.")
        let translation = kind.hasPrefix("response.audio_transcript.") || kind.hasPrefix("response.text.")
        guard source || translation, kind.hasSuffix(".delta") || kind.hasSuffix(".completed") || kind.hasSuffix(".done") else { return [] }
        guard let id = event["item_id"] as? String, !id.isEmpty else { throw BailianError("百炼字幕事件缺少消息ID。") }
        let key = (source ? "s:" : "t:") + id
        if text[key] == nil {
            order.append(key); text[key] = ""
            if order.count > 200 { text.removeValue(forKey:order.removeFirst()) }
        }
        let final = !kind.hasSuffix(".delta")
        if final {
            if let complete = (event["transcript"] ?? event["text"]) as? String { text[key] = complete }
        } else { text[key, default: ""] += event["delta"] as? String ?? "" }
        return [ASTResponse(event:source ? 660 : 661, text:text[key] ?? "", captionID:id, final:final,
                            sourceLanguage: source && final ? event["language"] as? String : nil)]
    }
}
