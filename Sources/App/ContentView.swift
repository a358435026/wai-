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
                Section {
                    Label(model.keySaved ? "已保存 API Key" : "尚未配置 API Key",
                          systemImage: model.keySaved ? "checkmark.shield" : "key")
                    SecureField(model.keySaved ? "输入新 Key 以替换" : "粘贴火山引擎 API Key", text: $key)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .accessibilityIdentifier("apiKeyField")
                    Button("保存并返回") {
                        do { try model.saveKey(key); key = ""; dismiss() }
                        catch { self.error = error.localizedDescription }
                    }.disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if model.keySaved {
                        Button("移除本机 API Key", role: .destructive) {
                            do { try model.deleteKey() } catch { self.error = error.localizedDescription }
                        }
                    }
                } header: { Text("个人自用凭据") } footer: {
                    Text("Key 仅存入本机钥匙串，不写入项目、日志或普通设置。请使用已开通同声传译服务的 Key，调用按火山引擎规则计费。")
                }
                Section("语音播放") {
                    Toggle("自动播放译音", isOn: $model.playbackEnabled)
                    Text("采用官方译音，默认跟随输入说话人的音色。")
                        .font(.footnote).foregroundStyle(.secondary)
                    Text("首版需保持应用在前台。进入后台或音频被中断时会结束连接；会话运行期间屏幕保持唤醒。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("服务与隐私") {
                    Link("开通同传服务 / API Key 管理", destination: URL(string: "https://console.volcengine.com/speech/new/setting/apikeys?projectName=default")!)
                    Link("官方同声传译文档", destination: URL(string: "https://docs.volcengine.com/docs/doubao-voice/simultaneous-interpretation?lang=zh")!)
                    Text("麦克风音频会实时发送至火山引擎。本应用不保存录音，字幕仅保留在当前内存会话中。与豆包 App 无账号关联。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
            }
            .navigationTitle("设置").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("完成") { dismiss() } } }
        }.navigationViewStyle(.stack).tint(teal)
    }
}
