import Foundation

/// Streams mono PCM16 at the Bailian playback rate using the existing workspace.
@MainActor
final class BailianSpeechSynthesis {
    private static let voices: [String: String] = [
        "zh": "longanlingxin_v3.1", "en": "longanlingxin_v3.1",
        "ar": "qwen-audio-3.1-tts-flash-naseem_ar", "es": "qwen-audio-3.1-tts-flash-albor_es",
        "ru": "qwen-audio-3.1-tts-flash-veter_ru", "pt": "qwen-audio-3.1-tts-flash-farol_pt",
        "tr": "qwen-audio-3.1-tts-flash-deniz_tr", "de": "longanlingxin_v3.1",
        "fr": "longanlingxin_v3.1", "it": "longanlingxin_v3.1",
        "ja": "longanlingxin_v3.1", "ko": "longanlingxin_v3.1",
        "vi": "longanlingxin_v3.1", "id": "longanlingxin_v3.1"
    ]

    private let endpoint: URL
    private let key: String
    private let session: URLSession

    init(host: String, key: String) {
        endpoint = URL(string: "https://\(host)/api/v1/services/audio/tts/SpeechSynthesizer")!
        self.key = key
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForResource = 16
        session = URLSession(configuration: config)
    }

    static func supports(_ language: String) -> Bool { voices[language] != nil }

    func stream(_ text: String, language: String, onPCM: (Data) throws -> Void) async throws {
        guard let voice = Self.voices[language] else { throw BailianError("云端音色不支持此语种。") }
        var request = URLRequest(url: endpoint, timeoutInterval: 5)
        request.httpMethod = "POST"
        request.setValue("Bearer " + key, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("enable", forHTTPHeaderField: "X-DashScope-SSE")
        var input: [String: Any] = ["text": text, "voice": voice, "format": "pcm", "sample_rate": 24000]
        if language != "zh" && language != "en" { input["language_hints"] = [language] }
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": "qwen-audio-3.1-tts-flash", "input": input
        ])

        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              http.mimeType == "text/event-stream" else { throw BailianError("云端译音连接失败。") }
        var received = false
        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            let event = try JSONDecoder().decode(Event.self, from: Data(payload.utf8))
            guard event.code == nil, let output = event.output else { throw BailianError("云端译音请求失败。") }
            if let encoded = output.audio?.data, !encoded.isEmpty {
                guard let pcm = Data(base64Encoded: encoded), !pcm.isEmpty, pcm.count.isMultiple(of: 2)
                else { throw BailianError("云端译音格式不正确。") }
                try onPCM(pcm)
                received = true
            }
            if output.finish_reason == "stop", received { return }
        }
        throw BailianError("云端译音未完整返回。")
    }

    func close() { session.invalidateAndCancel() }

    private struct Event: Decodable {
        struct Output: Decodable {
            struct Audio: Decodable { let data: String? }
            let finish_reason: String?
            let audio: Audio?
        }
        let code: String?
        let output: Output?
    }
}
