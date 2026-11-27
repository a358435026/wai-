import SwiftUI

// A visual cue only: flags do not change provider language, region or voice parameters.
struct LanguageEmblem: View {
    let code: String
    let provider: TranslationProvider
    var body: some View {
        Group {
            if let region = region {
                Text(region.unicodeScalars.compactMap { UnicodeScalar(127397 + $0.value) }
                    .map(String.init).joined()).font(.system(size: 23))
            } else {
                Image(systemName: "globe").font(.system(size: 22)).foregroundColor(VoiceTheme.accent)
            }
        }.frame(width: 30, height: 28).accessibilityHidden(true)
    }
    private var region: String? {
        if code == "bailian-auto" || code == "auto" || code == "zhen" { return nil }
        if ASTLanguages.dialects.contains(where: { $0.id == code }) || code == "yue" { return "CN" }
        if provider == .volcengine && code == "pt" { return "BR" }
        if provider == .volcengine && code == "es" { return "MX" }
        return Self.regions[code]
    }
    private static let regions = [
        "zh":"CN", "en":"GB", "pt":"PT", "es":"ES", "ja":"JP", "hi":"IN",
        "ko":"KR", "fr":"FR", "de":"DE", "ru":"RU", "ar":"SA", "id":"ID",
        "th":"TH", "vi":"VN", "it":"IT", "nl":"NL", "ro":"RO", "pl":"PL",
        "cs":"CZ", "sk":"SK", "bg":"BG", "uk":"UA", "lt":"LT", "lv":"LV",
        "el":"GR", "ga":"IE", "ca":"ES", "is":"IS", "da":"DK", "sv":"SE",
        "no":"NO", "nb":"NO", "fi":"FI", "et":"EE", "hu":"HU", "ms":"MY",
        "fil":"PH", "tr":"TR", "fa":"IR", "ur":"PK", "bn":"BD", "pa":"IN",
        "kk":"KZ", "uz":"UZ", "az":"AZ", "my":"MM", "km":"KH", "jv":"ID",
        "sw":"TZ", "he":"IL", "af":"ZA", "ast":"ES", "be":"BY", "bs":"BA",
        "ceb":"PH", "gl":"ES", "gu":"IN", "hr":"HR", "kn":"IN", "ky":"KG",
        "mk":"MK", "ml":"IN", "mr":"IN", "sl":"SI", "tg":"TJ"
    ]
}
