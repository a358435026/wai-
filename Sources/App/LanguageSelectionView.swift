import SwiftUI

struct LanguageSelectionView: View {
    let title: String
    let options: [ASTLanguage]
    let selected: String
    let showSpeechSupport: Bool
    var provider: TranslationProvider = .volcengine
    let select: (String) -> Void
    @State private var query = ""
    private var matches: [ASTLanguage] {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? options : options.filter {
            $0.name.localizedCaseInsensitiveContains(value) || $0.id.localizedCaseInsensitiveContains(value)
        }
    }
    var body: some View {
        List {
            if matches.isEmpty { Text("未找到该语言，请尝试语种名称或代码。").foregroundColor(.secondary) }
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
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索语言或代码")
        .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
    }
}
