import SwiftUI

private let teal = VoiceTheme.accent

@MainActor
struct SettingsView: View {
    @ObservedObject var model: InterpreterModel
    @Environment(\.dismiss) private var dismiss
    @State private var key = ""
    @State private var error: String?
    var body: some View {
        NavigationView {
            Form {
                Section("同传服务") {
                    Picker("服务商", selection: Binding(get: { model.provider }, set: { model.selectProvider($0) })) {
                        ForEach(TranslationProvider.allCases) { provider in Text(provider.title).tag(provider) }
                    }.pickerStyle(.segmented).accessibilityIdentifier("providerPicker").disabled(model.active)
                    Text(model.provider == .bailian ? "Qwen 3.8实时同传 · 自动识别源语言" : "火山豆包实时同传 · 可指定源语言")
                        .font(.footnote).foregroundColor(.secondary)
                    if model.provider == .bailian {
                        TextField("业务空间 API Host（不是 Key）", text: $model.bailianHost)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .accessibilityIdentifier("bailianHostField").disabled(model.active)
                        Text("在百炼业务空间管理复制API Host，例如 ws-xxx.cn-beijing.maas.aliyuncs.com。Key与Host必须属于同一业务空间和地域。")
                            .font(.footnote).foregroundColor(.secondary)
                    }
                }
                Section {
                    Label(model.keySaved ? "已保存 API Key" : "尚未配置 API Key",
                          systemImage: model.keySaved ? "checkmark.shield" : "key")
                    SecureField(model.keySaved ? "输入新 Key 以替换" : "粘贴\(model.provider.title) API Key", text: $key)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .accessibilityIdentifier("apiKeyField")
                        .submitLabel(.done).onSubmit { saveAndClose() }
                    if model.keySaved {
                        Button("移除本机 API Key", role: .destructive) {
                            do { try model.deleteKey() } catch { self.error = error.localizedDescription }
                        }
                    }
                } header: { Text("个人自用凭据") } footer: {
                    Text("两家Key分别保存在本机钥匙串，切换服务不会覆盖另一家的Key。本客户端供个人自用，不内置凭据；调用由当前服务商计费。")
                }
                Section("本机音频测试") {
                    Button("测试麦克风（不联网）") { dismiss(); model.testMicrophone() }.disabled(model.active)
                    Text("不需要 API Key，也不消耗服务额度。若已授权仍无法收音，可在连接诊断查看队列回调和设备信息。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("翻译输出") {
                    Toggle("仅字幕，不生成译音", isOn: $model.subtitlesOnly).disabled(model.active)
                    Text("这是服务端仅字幕模式，可避免生成译音。底部扬声器开关只控制本机播放。语言选择在首页顶部入口。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("语音播放") {
                    Toggle("自动播放译音", isOn: $model.playbackEnabled)
                    Text("采用官方译音。外放时轮流收说以避免回声；戴耳机可同时收听与说话。")
                        .font(.footnote).foregroundStyle(.secondary)
                    Text("首版需保持应用在前台。进入后台或音频被中断时会结束连接；会话运行期间屏幕保持唤醒。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("服务与隐私") {
                    Link("开通同传服务 / API Key 管理", destination: URL(string: model.provider == .bailian ? "https://bailian.console.aliyun.com/cn-beijing/settings/api-key" : "https://console.volcengine.com/speech/new/setting/apikeys?projectName=default")!)
                    Link("官方同声传译文档", destination: URL(string: model.provider == .bailian ? "https://help.aliyun.com/zh/model-studio/livetranslate-realtime-websocket-access" : "https://docs.volcengine.com/docs/doubao-voice/simultaneous-interpretation?lang=zh")!)
                    Text("麦克风音频会实时发送至你选择的\(model.provider.title)。本应用不保存录音，字幕仅保留在当前内存会话中。与豆包 App 无账号关联。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("设置").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("保存并返回") { saveAndClose() }
                        .disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("saveCredentials")
                }
                ToolbarItem(placement: .navigationBarTrailing) { Button("完成") { dismiss() } }
            }
        }.navigationViewStyle(.stack).tint(teal)
            .onChange(of: model.provider) { _ in key = ""; error = nil }
            .alert("无法保存设置", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("知道了", role: .cancel) { error = nil }
            } message: { Text(error ?? "请检查输入后重试。") }
    }
    private func saveAndClose() {
        do { try model.saveKey(key); key = ""; dismiss() }
        catch { self.error = error.localizedDescription }
    }
}
