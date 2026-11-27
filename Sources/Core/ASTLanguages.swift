import Foundation

public struct ASTLanguage: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let shortName: String
    public let dialect: Bool
    public let defaultSpeech: Bool
    init(_ id: String, _ name: String, short: String? = nil, dialect: Bool = false, speech: Bool? = nil) {
        self.id = id; self.name = name; shortName = short ?? name; self.dialect = dialect
        defaultSpeech = speech ?? Self.speechCodes.contains(id)
    }
    private static let speechCodes: Set<String> = ["zh", "en", "es", "pt", "de", "fr", "id", "ja",
        "ru", "it", "ko", "ar", "ms", "th", "vi", "fil"]
}

// Official AST 2.0 language table, checked 2026-11-26. Speech refers only to
// the default no-speaker-ID path implemented here; it is not a claim that
// custom/preset voice integrations cannot support additional languages.
public enum ASTLanguages {
    public static let spoken: [ASTLanguage] = [
        ASTLanguage("zh", "中文（普通话）", short: "中文"), ASTLanguage("en", "英语"),
        ASTLanguage("ja", "日语"), ASTLanguage("ko", "韩语"), ASTLanguage("fr", "法语"),
        ASTLanguage("de", "德语"), ASTLanguage("es", "西班牙语（墨西哥）", short: "西班牙语"),
        ASTLanguage("pt", "葡萄牙语（巴西）", short: "葡萄牙语"), ASTLanguage("ru", "俄语"),
        ASTLanguage("ar", "阿拉伯语"), ASTLanguage("id", "印尼语"), ASTLanguage("th", "泰语"),
        ASTLanguage("vi", "越南语"), ASTLanguage("it", "意大利语"), ASTLanguage("nl", "荷兰语"),
        ASTLanguage("ro", "罗马尼亚语"), ASTLanguage("pl", "波兰语"), ASTLanguage("cs", "捷克语"),
        ASTLanguage("sk", "斯洛伐克语"), ASTLanguage("bg", "保加利亚语"), ASTLanguage("uk", "乌克兰语"),
        ASTLanguage("lt", "立陶宛语"), ASTLanguage("lv", "拉脱维亚语"), ASTLanguage("el", "希腊语"),
        ASTLanguage("ga", "爱尔兰语"), ASTLanguage("ca", "加泰罗尼亚语"), ASTLanguage("is", "冰岛语"),
        ASTLanguage("da", "丹麦语"), ASTLanguage("sv", "瑞典语"), ASTLanguage("no", "挪威语"),
        ASTLanguage("fi", "芬兰语"), ASTLanguage("et", "爱沙尼亚语"), ASTLanguage("hu", "匈牙利语"),
        ASTLanguage("ms", "马来语"), ASTLanguage("fil", "菲律宾语"), ASTLanguage("tr", "土耳其语"),
        ASTLanguage("fa", "波斯语"), ASTLanguage("hi", "印地语"), ASTLanguage("ur", "乌尔都语"),
        ASTLanguage("bn", "孟加拉语"), ASTLanguage("pa", "旁遮普语"), ASTLanguage("kk", "哈萨克语"),
        ASTLanguage("uz", "乌兹别克语"), ASTLanguage("az", "阿塞拜疆语"), ASTLanguage("my", "缅甸语"),
        ASTLanguage("km", "高棉语"), ASTLanguage("jv", "爪哇语"), ASTLanguage("sw", "斯瓦希里语")
    ]
    public static let dialects: [ASTLanguage] = [
        ASTLanguage("yue-CN", "粤语", dialect: true), ASTLanguage("sh-CN", "上海话", dialect: true),
        ASTLanguage("nan", "闽南语", dialect: true), ASTLanguage("lany", "兰银官话", dialect: true),
        ASTLanguage("hak", "客家话", dialect: true), ASTLanguage("shaanxi", "中原官话", dialect: true),
        ASTLanguage("jilu", "冀鲁官话", dialect: true), ASTLanguage("jlua", "江淮官话", dialect: true),
        ASTLanguage("sc", "四川话", dialect: true)
    ]
    public static let sources = spoken + dialects + [ASTLanguage("auto", "中英混合识别")]
    public static func source(_ code: String) -> ASTLanguage? { sources.first { $0.id == code } }
    public static func target(_ code: String) -> ASTLanguage? { spoken.first { $0.id == code } }
    public static func targets(for source: String) -> [ASTLanguage] {
        spoken.filter { validationError(source: source, target: $0.id) == nil }
    }
    public static func validationError(source: String, target: String) -> String? {
        guard let input = self.source(source), self.target(target) != nil else { return "请选择受支持的语言。" }
        guard source != target else { return "源语言与目标语言需要不同。" }
        let core: Set<String> = ["zh", "en"]
        if input.dialect || source == "auto" {
            return core.contains(target) ? nil : "方言和中英混合识别只能译为中文或英语。"
        }
        return core.contains(source) || core.contains(target) ? nil : "当前接口要求至少一端为中文或英语。"
    }
    public static func mode(target: String, subtitlesOnly: Bool) -> ASTMode {
        subtitlesOnly || self.target(target)?.defaultSpeech != true ? .subtitles : .speechToSpeech
    }
}
