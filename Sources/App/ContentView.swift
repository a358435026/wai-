import SwiftUI

private let teal = Color(red: 0.08, green: 0.39, blue: 0.34)

@MainActor
struct ContentView: View {
    @StateObject private var model = InterpreterModel()
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    header
                    directionPicker
                    statusCard
                    if let error = model.errorMessage {
                        Label(error, systemImage: "exclamationmark.circle")
                            .font(.subheadline).foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding().background(.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
                            .accessibilityIdentifier("errorMessage")
                    }
                    captionCard(title: "原文", subtitle: "ORIGINAL", captions: model.source.captions,
                                empty: "你说的话会出现在这里", translated: false)
                    captionCard(title: "译文", subtitle: "TRANSLATION", captions: model.translation.captions,
                                empty: "翻译会实时显示，并自动播报", translated: true)
                    if model.phase == .live {
                        HStack(spacing: 12) {
                            Button { model.micMuted.toggle() } label: {
                                Label(model.micMuted ? "打开麦克风" : "麦克风", systemImage: model.micMuted ? "mic.slash" : "mic")
                                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                            }.buttonStyle(.bordered)
                            Button { model.playbackEnabled.toggle() } label: {
                                Label(model.playbackEnabled ? "译音已开启" : "译音已静音",
                                      systemImage: model.playbackEnabled ? "speaker.wave.2" : "speaker.slash")
                                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                            }.buttonStyle(.bordered)
                        }.tint(teal)
                        if model.micMuted {
                            Text("麦克风已静音，会话仍在运行并可能计费。结束使用请点停止。")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Button {
                        if model.active { model.stop() } else { model.start() }
                    } label: {
                        Label(buttonTitle, systemImage: model.active ? "stop.fill" : "waveform")
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 19)
                    }
                    .buttonStyle(.borderedProminent).tint(model.active ? Color.primary : teal)
                    .disabled(model.phase == .finishing).accessibilityIdentifier("mainAction")
                    Text("使用火山引擎官方同传服务 · 需要联网\n音频会发送至火山引擎，本应用不保存录音。")
                        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        .padding(.bottom, 18)
                }.padding(.horizontal, 22).padding(.top, 12)
            }
            .background(Color(red: 0.96, green: 0.97, blue: 0.95))
            .navigationTitle("随声同传").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { model.showSettings = true } label: { Image(systemName: "slider.horizontal.3") }
                        .accessibilityLabel("设置").disabled(model.active)
                }
            }
            .sheet(isPresented: $model.showSettings) { SettingsView(model: model) }
        }.tint(teal)
    }
    private var buttonTitle: String {
        switch model.phase {
        case .idle: return model.keySaved ? "开始同传" : "配置 API Key"
        case .connecting: return "取消连接"
        case .live: return "停止同传"
        case .finishing: return "正在收尾…"
        }
    }
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("让对话，\n自然发生。").font(.system(size: 34, weight: .semibold, design: .rounded))
            Text("实时双语字幕 · 听得见的翻译").font(.subheadline).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
    }
    private var directionPicker: some View {
        HStack {
            Image(systemName: "globe").foregroundStyle(teal)
            Picker("翻译方向", selection: $model.direction) {
                ForEach(model.directions.indices, id: \.self) { Text(model.directions[$0]).tag($0) }
            }.pickerStyle(.menu).tint(.primary).disabled(model.active)
            Spacer()
            Text("S2S").font(.caption.monospaced()).foregroundStyle(teal)
        }.padding(12).background(.white, in: RoundedRectangle(cornerRadius: 18))
    }
    private var statusCard: some View {
        HStack(spacing: 16) {
            Image(systemName: model.playing ? "speaker.wave.2.fill" : "waveform")
                .font(.system(size: 25)).foregroundStyle(teal)
                .frame(width: 62, height: 62)
                .background(teal.opacity(model.active ? 0.18 : 0.08), in: Circle())
                .symbolEffect(.variableColor, isActive: model.phase == .live)
            VStack(alignment: .leading, spacing: 6) {
                Text(model.playing ? "正在播放译音" : model.status).font(.headline)
                Text(model.active ? model.route : "戴上耳机，或直接使用扬声器")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if model.phase == .connecting || model.phase == .finishing { ProgressView() }
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(teal.opacity(0.05), in: RoundedRectangle(cornerRadius: 22))
    }
    private func captionCard(title: String, subtitle: String, captions: [Caption], empty: String,
                             translated: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title).font(.headline)
                Text(subtitle).font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1.5)
                    .foregroundStyle(.secondary)
                Spacer()
                if translated && model.playing { Image(systemName: "speaker.wave.2.fill").foregroundStyle(teal) }
            }
            if captions.allSatisfy({ $0.text.isEmpty }) {
                Text(empty).foregroundStyle(.secondary).font(.body).padding(.vertical, 10)
            } else {
                ForEach(captions.suffix(8)) { caption in
                    if !caption.text.isEmpty {
                        Text(caption.text).font(.system(size: translated ? 22 : 18, weight: translated ? .medium : .regular))
                            .foregroundStyle(translated ? teal : Color.primary)
                            .opacity(caption.final ? 1 : 0.7).textSelection(.enabled)
                    }
                }
            }
        }.frame(maxWidth: .infinity, minHeight: 94, alignment: .topLeading)
            .padding(20).background(.white, in: RoundedRectangle(cornerRadius: 22))
    }
}

@MainActor
private struct SettingsView: View {
    @ObservedObject var model: InterpreterModel
    @Environment(\.dismiss) private var dismiss
    @State private var key = ""
    @State private var error: String?
    var body: some View {
        NavigationStack {
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
                    Text("采用官方 S2S 译音。未指定音色时，服务默认跟随输入说话人的音色。")
                        .font(.footnote).foregroundStyle(.secondary)
                    Text("首版需保持应用在前台。进入后台或音频被中断时会结束连接；会话运行期间屏幕保持唤醒。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("服务与隐私") {
                    Link("开通同传服务 / API Key 管理", destination: URL(string: "https://console.volcengine.com/speech/new/setting/apikey")!)
                    Link("官方同声传译文档", destination: URL(string: "https://docs.volcengine.com/docs/doubao-voice/simultaneous-interpretation?lang=zh")!)
                    Text("麦克风音频会实时发送至火山引擎。本应用不保存录音，字幕仅保留在当前内存会话中。与豆包 App 无账号关联。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
            }
            .navigationTitle("设置").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } }
        }.tint(teal)
    }
}
