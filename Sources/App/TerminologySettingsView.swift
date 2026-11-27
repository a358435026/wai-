import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct TerminologySettingsView: View {
    @ObservedObject var model: InterpreterModel
    @State private var draft = ""
    @State private var importing = false
    @State private var error: String?
    @State private var saved = false
    var body: some View {
        Form {
            Section {
                Toggle("启用外贸术语", isOn: $model.terminologyEnabled).disabled(model.active)
                    .accessibilityIdentifier("terminologyEnabled")
                Text("内置30组电动车与外贸常用术语，支持中、英、葡、西互译。其他语种可导入自己的词。下次连接时随请求交给当前服务，译音也由服务生成；无需另下载模型。")
                    .font(.footnote).foregroundColor(.secondary)
            }
            Section("自定义词表的方向") {
                Picker("原文语言", selection: $model.termsSource) {
                    ForEach(BailianLanguages.targets) { Text($0.name).tag($0.id) }
                }
                Picker("译入语言", selection: $model.termsTarget) {
                    ForEach(BailianLanguages.targets) { Text($0.name).tag($0.id) }
                }
                Text("仅在目标语种和方向匹配时使用，避免把英文词表发给葡语会话。百炼自动识别时按原词匹配。")
                    .font(.footnote).foregroundColor(.secondary)
            }.disabled(model.active)
            Section("自定义词：原文与译文两列") {
                TextEditor(text: $draft).font(.body).frame(minHeight: 180)
                    .accessibilityIdentifier("customTermsEditor").disabled(model.active)
                Button("导入 CSV / TSV / JSON 文件") { importing = true }.disabled(model.active)
                    .accessibilityIdentifier("importTerms")
                Button("填入示例（会替换编辑内容）") { draft = TradeTerminology.examples; saved = false }.disabled(model.active)
                    .accessibilityIdentifier("sampleTerms")
                Button("保存词表") { save() }.disabled(model.active).accessibilityIdentifier("saveTerms")
                if saved { Label("词表已保存，下次连接生效", systemImage: "checkmark.circle").font(.footnote) }
                Text("最多100条自定义词、32KB。可用两列CSV（含引号）、Tab文本，或JSON对象。自定义词优先于内置词；精确型号、参数和单位建议由你校对。术语是模型指导，不能保证每次强制命中。")
                    .font(.footnote).foregroundColor(.secondary)
            }
            Section("本次配置") {
                Text("当前会话将发送 \(model.glossaryCount) 条术语。")
                Text("词表保存在本机；开启后会随会话发送给所选服务商，不会自动公开上传到词库市场。")
                    .font(.footnote).foregroundColor(.secondary)
            }
        }.navigationTitle("外贸术语").navigationBarTitleDisplayMode(.inline)
            .onAppear { draft = model.customTerms }
            .onChange(of: draft) { _ in saved = false }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.commaSeparatedText, .tabSeparatedText, .plainText, .json]) { result in
                do {
                    let url = try result.get()
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    guard size <= 32_000 else { throw BailianError("文件超过32KB，请精简后再导入。") }
                    let value = try String(contentsOf: url, encoding: .utf8)
                    _ = try TradeTerminology.parse(value); draft = value; saved = false
                } catch { self.error = error.localizedDescription }
            }
            .alert("词表未保存", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("知道了", role: .cancel) { error = nil }
            } message: { Text(error ?? "请检查词表格式。") }
    }
    private func save() {
        do { _ = try TradeTerminology.parse(draft); model.customTerms = draft; saved = true }
        catch { self.error = error.localizedDescription }
    }
}
