import Foundation
#if canImport(NaturalLanguage)
import NaturalLanguage
#endif

public struct ConversationTurnRouting {
    public private(set) var lastForeignLanguage: String?

    public init() {}

    #if canImport(NaturalLanguage)
    public static func languageHypotheses(for text: String) -> [String: Double] {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return Dictionary(uniqueKeysWithValues: recognizer.languageHypotheses(withMaximum: 3).map {
            ($0.key.rawValue, $0.value)
        })
    }
    #endif

    public mutating func route(text: String, providerLanguage: String? = nil, hypotheses: [String: Double],
                               fallback: String, supported: Set<String>) -> String {
        let ranked = hypotheses.sorted { $0.value > $1.value }
        let best = ranked.first
        let serverTag = Self.baseLanguage(providerLanguage)
        let tag = serverTag ?? Self.baseLanguage(best?.key)
        let target = Self.destination(text: text, detected: tag, reply: lastForeignLanguage ?? fallback)
        guard target == "zh" else { return target }

        // Short interjections and product names are often shared across languages.
        let letterCount = text.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
        let wordCount = text.split { !$0.isLetter }.count
        let distinctiveSpanish = text.contains("¿") || text.contains("¡")
        let enoughText = letterCount >= 5 && (wordCount >= 2 || ["ja", "ko", "th"].contains(tag ?? ""))
        let confidence = best?.value ?? 0
        let margin = confidence - (ranked.dropFirst().first?.value ?? 0)
        if distinctiveSpanish, supported.contains("es") {
            lastForeignLanguage = "es"
        } else if let tag, tag != "zh", supported.contains(tag), enoughText,
                  serverTag != nil || (confidence >= 0.55 && margin >= 0.18) {
            lastForeignLanguage = tag
        } else if serverTag == nil, tag == nil || tag == "ar", supported.contains("ar"),
                  wordCount >= 2, text.contains("ة"), text.contains("ال") {
            lastForeignLanguage = "ar"
        }
        return "zh"
    }

    private static func baseLanguage(_ value: String?) -> String? {
        guard let tag = value?.lowercased().split(whereSeparator: { $0 == "-" || $0 == "_" }).first,
              (2...3).contains(tag.count), tag != "und", tag != "auto" else { return nil }
        return String(tag)
    }

    public static func destination(text: String, detected: String?, reply: String) -> String {
        let tag = detected?.lowercased()
        // Kana distinguishes Japanese even when many of the characters are shared with Chinese.
        if text.unicodeScalars.contains(where: { (0x3040...0x30ff).contains($0.value) }) { return "zh" }
        if tag == "zh" || tag?.hasPrefix("zh-") == true { return reply }
        let letters = text.unicodeScalars.filter { CharacterSet.letters.contains($0) }
        let han = letters.filter {
            (0x3400...0x9fff).contains($0.value) || (0x20000...0x2fa1f).contains($0.value)
        }
        if let tag, tag != "und", tag != "ja" { return "zh" }
        return !han.isEmpty && han.count * 2 >= letters.count ? reply : "zh"
    }
}
