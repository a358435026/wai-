import SwiftUI

struct LanguageSelectionView: View {
    let title: String
    let options: [ASTLanguage]
    let selected: String
    let showSpeechSupport: Bool
    var provider: TranslationProvider = .volcengine
    let select: (String) -> Void
    @State private var query = ""
    @State private var outputFilter: OutputFilter = .all
    private enum OutputFilter: String, CaseIterable, Hashable {
        case all = "全部"
        case speech = "可播报"
        case captions = "仅字幕"

        func includes(_ language: ASTLanguage) -> Bool {
            switch self {
            case .all: return true
            case .speech: return language.defaultSpeech
            case .captions: return !language.defaultSpeech
            }
        }
    }
    private let english = Locale(identifier: "en")
    private var matches: [ASTLanguage] {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return options.filter { language in
            guard !showSpeechSupport || outputFilter.includes(language) else { return false }
            return value.isEmpty || [language.name, language.shortName, language.id,
                english.localizedString(forLanguageCode: language.id) ?? ""].contains {
                $0.localizedStandardContains(value)
            }
        }
    }
    var body: some View {
        List {
            if showSpeechSupport {
                Picker("输出能力", selection: $outputFilter) {
                    ForEach(OutputFilter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented).accessibilityIdentifier("languageOutputFilter")
            }
            if matches.isEmpty { Text("没有符合条件的语言。试试其他名称、代码或筛选条件。").foregroundColor(.secondary) }
            ForEach(matches) { language in
                Button {
                    select(language.id)
                } label: {
                    HStack(spacing: 12) {
                        LanguageEmblem(code: language.id, provider: provider)
                        VStack(alignment: .leading) {
                            Text(language.name).foregroundColor(VoiceTheme.ink)
                            if showSpeechSupport {
                                Label(language.defaultSpeech ? "字幕与译音" : "本版仅字幕",
                                      systemImage: language.defaultSpeech ? "speaker.wave.2" : "text.bubble")
                                    .font(.caption).foregroundColor(.secondary)
                            } else if language.dialect {
                                Text("方言输入").font(.caption).foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        if language.id == selected { Image(systemName: "checkmark").foregroundColor(VoiceTheme.accent) }
                    }
                }.accessibilityIdentifier("language-\(language.id)")
            }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索中文、英文或语言代码")
        .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
    }
}
