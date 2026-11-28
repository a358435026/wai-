import Foundation
import NaturalLanguage

struct BailianTextTranslation {
    private let endpoint: URL
    private let key: String
    private let session = URLSession(configuration: .ephemeral)

    init(host: String, key: String) throws {
        let validated = try BailianWire.normalizedHost(host)
        endpoint = URL(string: "https://\(validated)/compatible-mode/v1/chat/completions")!
        self.key = key
    }

    static func destination(for text: String, reply: String) -> String {
        ConversationTurnRouting.destination(
            text: text, detected: NLLanguageRecognizer.dominantLanguage(for: text)?.rawValue, reply: reply
        )
    }

    func translate(_ text: String, to target: String, terms: [String: String]) async throws -> String {
        var request = URLRequest(url: endpoint, timeoutInterval: 8)
        request.httpMethod = "POST"
        request.setValue("Bearer " + key, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var options: [String: Any] = ["source_lang": "auto", "target_lang": target]
        let matches = terms.sorted { $0.key < $1.key }.filter {
            text.localizedCaseInsensitiveContains($0.key)
        }
        if !matches.isEmpty {
            options["terms"] = matches.prefix(20).map { ["source": $0.key, "target": $0.value] }
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": "qwen-mt-flash",
            "messages": [["role": "user", "content": text]],
            "translation_options": options
        ])
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw BailianError("文字翻译失败（HTTP \(code)）。请检查百炼 qwen-mt-flash 权限与额度。")
        }
        let decoded = try JSONDecoder().decode(Completion.self, from: data)
        guard let result = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines), !result.isEmpty
        else { throw BailianError("百炼没有返回这句话的译文。") }
        return result
    }

    func close() { session.invalidateAndCancel() }

    private struct Completion: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { let content: String }
            let message: Message
        }
        let choices: [Choice]
    }
}
