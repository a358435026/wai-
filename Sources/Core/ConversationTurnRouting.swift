import Foundation

public enum ConversationTurnRouting {
    public static func destination(text: String, detected: String?, reply: String) -> String {
        let tag = detected?.lowercased()
        // Kana distinguishes Japanese even when many of the characters are shared with Chinese.
        if text.unicodeScalars.contains(where: { (0x3040...0x30ff).contains($0.value) }) { return "zh" }
        if tag == "zh" || tag?.hasPrefix("zh-") == true { return reply }
        if let tag, tag != "und" { return "zh" }
        let letters = text.unicodeScalars.filter { CharacterSet.letters.contains($0) }
        let han = letters.filter {
            (0x3400...0x9fff).contains($0.value) || (0x20000...0x2fa1f).contains($0.value)
        }
        return !han.isEmpty && han.count * 2 >= letters.count ? reply : "zh"
    }
}
