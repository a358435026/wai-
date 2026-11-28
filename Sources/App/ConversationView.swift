import SwiftUI

@MainActor
struct ContentView: View {
    @StateObject private var model = InterpreterModel()
    @State private var showCaptions = true
    @State private var showScenes = false
    @State private var quickLanguagePicker: LanguageField?
    @State private var pendingQuickLanguage: String?
    @State private var confirmListening = false
    @State private var sourcePickerOpen = false
    @State private var targetPickerOpen = false
    @State private var showDiagnostics = false
    @State private var showMore = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var hasCaptions: Bool {
        model.source.captions.contains { !$0.text.isEmpty } || model.translation.captions.contains { !$0.text.isEmpty }
    }
    var body: some View {
        VStack(spacing: 14) {
            toolbar
            languageBar
            listeningControls
            ScrollViewReader { reader in
                ScrollView {
                    VStack(spacing: 18) {
                        HStack(spacing: 8) {
                            Circle().fill(model.phase == .live ? Color.green : VoiceTheme.muted).frame(width: 6, height: 6)
                                .accessibilityHidden(true)
                            Button { if model.playing { model.interruptPlayback() } } label: {
                                Text(statusTitle).font(.caption).foregroundColor(.secondary)
                            }.disabled(!model.playing).accessibilityIdentifier("voiceStatus")
                            Spacer(minLength: 0)
                        }
                        if let error = model.errorMessage { errorCard(error) }
                        if model.errorMessage == nil {
                        VoiceOrb(level: model.inputLevel, output: model.outputLevel,
                                 active: model.phase == .live, playing: model.playing)
                            .frame(width: hasCaptions && showCaptions ? 108 : 158,
                                   height: hasCaptions && showCaptions ? 108 : 158)
                            .accessibilityLabel(model.playing ? "正在播放译音" : (model.active ? "正在收音" : "语音待机"))
                        }
                        if showCaptions && hasCaptions {
                            ConversationTranscript(model: model)
                        } else if model.errorMessage == nil {
                            VStack(spacing: 12) {
                                Text(model.localTest ? "对着手机说话" : (model.active ? "你说的话，会在这里呈现" : "下一段对话，\n从这里开始。"))
                                    .font(.title2.weight(.semibold)).multilineTextAlignment(.center)
                                Text(model.localTest ? "观察语音球与诊断中的收音数据\n本机测试不联网，不消耗额度" : (showCaptions ? "用熟悉的语言表达\n原文与译文将实时呈现" : "字幕已隐藏，翻译与译音不受影响"))
                                    .font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
                            }.padding(.vertical, 18).frame(maxWidth: .infinity)
                        }
                        sessionNotes
                        Color.clear.frame(height: 1).id("latest")
                    }.padding(.horizontal, 22).padding(.top, 8).padding(.bottom, 14)
                }
                .onChange(of: model.translation.captions) { _ in reader.scrollTo("latest", anchor: .bottom) }
                .onChange(of: model.source.captions) { _ in reader.scrollTo("latest", anchor: .bottom) }
                .onChange(of: model.errorMessage) { value in if value != nil { reader.scrollTo("latest", anchor: .bottom) } }
            }
            controls
        }
        .frame(maxWidth: 700).frame(maxWidth: .infinity)
        .foregroundColor(VoiceTheme.ink).background(VoiceTheme.background.ignoresSafeArea())
        .sheet(isPresented: $model.showSettings) { SettingsView(model: model) }
        .sheet(isPresented: $showScenes) { sceneSheet }
        .sheet(item: $quickLanguagePicker) { field in quickLanguageSheet(field) }
        .sheet(isPresented: $showDiagnostics) { diagnostics }
        .confirmationDialog("更多操作", isPresented: $showMore, titleVisibility: .hidden) {
            Button("设置") { model.showSettings = true }.disabled(model.active)
            Button("语言与输出") { showScenes = true }.disabled(model.active)
            Button("连接诊断 / 测试收音") { showDiagnostics = true }
            Button("清空字幕", role: .destructive) { model.clearCaptions() }.disabled(model.active)
            Button("取消", role: .cancel) {}
        }
        .alert("切换到听外语", isPresented: $confirmListening) {
            Button("结束并切换") { model.enterChineseListening() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("当前会话结束后切到百炼。再次点“开始同传”，自动识别外语并译成中文。")
        }
        .tint(VoiceTheme.accent)
    }
    private var toolbar: some View {
        HStack {
            Text("随声同传").font(.title2.weight(.bold))
            Spacer()
            Button { showCaptions.toggle() } label: {
                Image(systemName: showCaptions ? "captions.bubble.fill" : "captions.bubble")
                    .font(.title3).frame(width: 44, height: 44)
            }.accessibilityLabel(showCaptions ? "隐藏字幕" : "显示字幕")
            Button { showMore = true } label: {
                Image(systemName: "slider.horizontal.3").font(.title3).frame(width: 44, height: 44)
                    .background(VoiceTheme.surface, in: Circle())
            }.accessibilityLabel("更多选项").accessibilityIdentifier("moreOptions")
        }.padding(.horizontal, 22).padding(.top, 8).buttonStyle(.plain)
    }
    private var languageBar: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 8) {
                    HStack { sourceLanguageButton; swapLanguageButton }
                    Divider()
                    targetLanguageButton
                }
            } else {
                HStack(spacing: 2) { sourceLanguageButton; swapLanguageButton; targetLanguageButton }
            }
        }.padding(7).background(VoiceTheme.surface, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(VoiceTheme.line, lineWidth: 1))
            .padding(.horizontal, 20).buttonStyle(.plain)
    }
    private var sourceLanguageButton: some View {
        Button { quickLanguagePicker = .source } label: {
            languageCell(title: "说话语言", language: model.sourceLanguage, selectable: model.provider != .bailian)
        }
            .accessibilityLabel("说话语言：\(model.sourceLanguage.name)")
            .accessibilityIdentifier("homeSourceLanguage")
            .disabled(model.provider == .bailian || !canPickLanguage)
    }
    private var targetLanguageButton: some View {
        Button { quickLanguagePicker = .target } label: { languageCell(title: "译为", language: model.targetLanguage) }
            .accessibilityLabel(model.translationTitle).accessibilityIdentifier("scenePicker")
            .disabled(!canPickLanguage)
    }
    private var swapLanguageButton: some View {
        Button { model.swapLanguages() } label: {
            Image(systemName: "arrow.left.arrow.right").font(.body.weight(.medium))
                .frame(minWidth: 44, minHeight: 44).padding(4)
                .background(VoiceTheme.soft, in: RoundedRectangle(cornerRadius: 12))
        }.disabled(!model.canSwap || model.active).accessibilityLabel(model.provider == .bailian ? "自动识别源语言，无需交换" : "交换翻译方向")
            .accessibilityIdentifier("quickSwapLanguages")
    }
    private var canPickLanguage: Bool {
        !model.localTest && (model.phase == .idle || model.phase == .live)
    }
    private func languageCell(title: String, language: ASTLanguage, selectable: Bool = true) -> some View {
        HStack(spacing: 6) {
            LanguageEmblem(code: language.id, provider: model.provider)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.caption2).foregroundColor(.secondary)
                Text(language.id == "en" ? "English" : language.shortName)
                    .font(.subheadline.weight(.semibold)).lineLimit(2)
            }
            Spacer(minLength: 0)
            if selectable {
                Image(systemName: "chevron.down").font(.caption2).foregroundColor(.secondary)
            }
        }.frame(maxWidth: .infinity, minHeight: 48).padding(.horizontal, 4).contentShape(Rectangle())
    }
    private func quickLanguageSheet(_ field: LanguageField) -> some View {
        let selected = field == .source ? model.sourceCode : model.targetCode
        let choices = field == .source ? ASTLanguages.sources : model.availableTargets
        return NavigationView {
            LanguageSelectionView(title: field == .source ? "说话语言" : "目标语言",
                options: choices, selected: selected, showSpeechSupport: field == .target,
                provider: model.provider) { code in
                    if code == selected && !model.bidirectional { quickLanguagePicker = nil; return }
                    if model.active { pendingQuickLanguage = code }
                    else { applyQuickLanguage(field, code: code) }
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("完成") { quickLanguagePicker = nil }
                    }
                }
                .alert("切换语言", isPresented: Binding(
                    get: { pendingQuickLanguage != nil },
                    set: { if !$0 { pendingQuickLanguage = nil } }
                ), presenting: pendingQuickLanguage) { code in
                    Button("结束并应用") { applyQuickLanguage(field, code: code) }
                    Button("取消", role: .cancel) { pendingQuickLanguage = nil }
                } message: { _ in
                    Text("先完成当前同传，再应用新语言。准备好后点“开始同传”。")
                }
        }.navigationViewStyle(.stack)
    }
    private func applyQuickLanguage(_ field: LanguageField, code: String) {
        model.requestLanguageChange(field, code: code)
        pendingQuickLanguage = nil
        quickLanguagePicker = nil
    }
    private var sessionNotes: some View {
        VStack(spacing: 8) {
            if model.phase == .connecting || model.phase == .finishing { ProgressView() }
            if model.localTest { Text("本机麦克风测试 · 不联网") }
            if !model.switchNotice.isEmpty { Text(model.switchNotice).accessibilityIdentifier("switchNotice") }
            if let delay = model.firstTranslationDelay { Text(String(format: "原文完成至首译 %.1f 秒", delay)) }
            if model.micMuted && model.active { Text("麦克风已静音，会话仍可能计费") }
            if model.readsChineseOnFinish && !model.localTest {
                Text("持续收音，结束后朗读中文")
            } else if !model.producesSpeech && !model.localTest {
                Text("仅字幕：本次不生成译音").accessibilityIdentifier("outputModeHint")
            }
            if model.canReadChineseCaptions {
                Button { model.readChineseCaptions() } label: {
                    Label("朗读中文译文", systemImage: "speaker.wave.2")
                }.buttonStyle(.bordered)
            }
            if model.capturePausedForSpeaker { Text("外放播报中 · 暂停上传收音防止回声") }
            if model.active && !model.localTest { Text(model.route) }
        }.font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
    }
    private var listeningControls: some View {
        HStack {
            if model.listenChinese {
                Button("回到说中文") { model.exitChineseListening() }.disabled(model.active)
                Spacer()
                Toggle("听完再播", isOn: $model.deferChineseSpeech)
                    .fixedSize().disabled(model.active || model.subtitlesOnly)
                    .accessibilityIdentifier("deferChineseSpeech")
            } else {
                Button {
                    if model.active { confirmListening = true }
                    else { model.enterChineseListening() }
                } label: {
                    Label("听外语 → 中文", systemImage: "ear")
                }.disabled(!canPickLanguage).accessibilityIdentifier("listenChinese")
                Spacer()
            }
        }.font(.subheadline).padding(.horizontal, 24)
    }
    private var statusTitle: String {
        if model.playing { return "正在播报 · 点击打断" }
        if model.localTest && model.phase == .live { return "对着手机说话，观察声音变化" }
        if model.phase == .live { return model.micMuted ? "麦克风已静音" : "正在聆听" }
        if model.active { return model.status }
        if !model.keySaved { return "先配置 API Key" }
        return model.status
    }
    private func errorCard(_ error: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("连接未完成", systemImage: "exclamationmark.circle").font(.headline)
            Text(error).font(.footnote).accessibilityIdentifier("errorMessage")
            HStack {
                Button("重新连接") { model.start() }.disabled(model.active)
                Spacer()
                Button("连接诊断") { showDiagnostics = true }
            }.font(.subheadline.weight(.semibold)).frame(minHeight: 44)
            Button("检查服务和 Key") { model.showSettings = true }
                .font(.subheadline.weight(.semibold)).disabled(model.active)
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(VoiceTheme.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.red.opacity(0.35), lineWidth: 1))
    }
    private var controls: some View {
        VStack(spacing: 10) {
            if dynamicTypeSize.isAccessibilitySize {
                mainAction
                HStack { micControl; Spacer(); speakerControl }
            } else {
                HStack(alignment: .top, spacing: 12) { micControl; mainAction; speakerControl }
            }
            Button { model.showSettings = true } label: {
                HStack(spacing: 5) {
                    Text(dynamicTypeSize.isAccessibilitySize ? model.provider.title : "\(model.provider.title) · \(model.provider == .bailian ? "自动识别源语言" : "固定翻译方向")")
                    Image(systemName: "chevron.right").font(.caption2)
                }.font(.caption).foregroundColor(.secondary).frame(minHeight: 36)
            }.disabled(model.active).accessibilityIdentifier("currentProvider")
        }.padding(.horizontal, 22).padding(.top, 14).padding(.bottom, 8)
            .background(VoiceTheme.background).overlay(alignment: .top) { VoiceTheme.line.frame(height: 1) }
    }
    private var mainAction: some View {
        let title = model.phase == .connecting ? "取消连接" : model.active ? "结束同传" : "开始同传"
        return Button { if model.active { model.stop() } else { model.start() } } label: {
            HStack(spacing: 8) {
                if model.phase == .connecting { ProgressView().tint(VoiceTheme.onAccent) }
                else { Image(systemName: model.active ? "stop.fill" : "waveform") }
                Text(title).fontWeight(.semibold)
            }.font(.body).frame(maxWidth: .infinity, minHeight: 54)
                .foregroundColor(VoiceTheme.onAccent)
                .background(VoiceTheme.accent, in: RoundedRectangle(cornerRadius: 15))
        }.accessibilityLabel(title)
            .accessibilityIdentifier("mainAction").disabled(model.phase == .finishing).buttonStyle(.plain)
    }
    private var micControl: some View {
        VStack(spacing: 6) {
            Button { model.micMuted.toggle() } label: {
                Image(systemName: model.micMuted ? "mic.slash" : "mic")
                    .font(.title3).frame(width: 54, height: 54)
                    .background(VoiceTheme.surface, in: RoundedRectangle(cornerRadius: 15))
            }.disabled(model.phase != .live).accessibilityLabel(model.micMuted ? "打开麦克风" : "麦克风静音")
            Text(model.micMuted ? "已静音" : "收音").font(.caption2).foregroundColor(.secondary)
        }.buttonStyle(.plain)
    }
    private var speakerControl: some View {
        let canSpeak = model.producesSpeech || model.readsChineseOnFinish
        return VStack(spacing: 6) {
            Button { model.playbackEnabled.toggle() } label: {
                Image(systemName: model.playbackEnabled && canSpeak ? "speaker.wave.2" : "speaker.slash")
                    .font(.title3).frame(width: 54, height: 54)
                    .background(VoiceTheme.surface, in: RoundedRectangle(cornerRadius: 15))
            }.disabled(!canSpeak)
                .accessibilityLabel(!canSpeak ? "仅字幕模式" : (model.playbackEnabled ? "关闭译音" : "开启译音"))
            Text(!canSpeak ? "仅字幕" : !model.playbackEnabled ? "已静音" : model.readsChineseOnFinish ? "结束后播" : "译音开启")
                .font(.caption2).foregroundColor(.secondary)
        }.buttonStyle(.plain)
    }
    private var sceneSheet: some View {
        NavigationView {
            Form {
                Section("翻译语言") {
                    if model.provider == .bailian {
                        HStack { Text("源语言"); Spacer(); Text("自动识别（60语种）").foregroundColor(.secondary) }
                    } else {
                    NavigationLink(isActive: $sourcePickerOpen) {
                        LanguageSelectionView(title: "源语言", options: ASTLanguages.sources,
                            selected: model.sourceCode, showSpeechSupport: false, provider: model.provider) { code in
                                model.selectSource(code); sourcePickerOpen = false
                            }
                    } label: {
                        HStack { Text("源语言"); Spacer(); Text(model.sourceLanguage.name).foregroundColor(.secondary) }
                    }.accessibilityIdentifier("sourceLanguagePicker")
                    }
                    NavigationLink(isActive: $targetPickerOpen) {
                        LanguageSelectionView(title: "目标语言", options: model.availableTargets,
                            selected: model.targetCode, showSpeechSupport: true, provider: model.provider) { code in
                                model.selectTarget(code); targetPickerOpen = false
                            }
                    } label: {
                        HStack { Text("目标语言"); Spacer(); Text(model.targetLanguage.name).foregroundColor(.secondary) }
                    }.accessibilityIdentifier("targetLanguagePicker")
                    if model.provider == .volcengine {
                    Button { model.swapLanguages() } label: {
                        Label("交换源语言与目标语言", systemImage: "arrow.up.arrow.down")
                    }.disabled(!model.canSwap).accessibilityIdentifier("swapLanguages")
                    }
                    Text(model.provider == .bailian ? "百炼自动识别源语言。60种译入语言中29种可播报；其余自动仅字幕。" : "当前接口要求至少一端为中文或英语。方言仅作为输入；中英混合识别只能译成中文或英语。")
                        .font(.footnote).foregroundColor(.secondary)
                }
                Section("输出方式") {
                    Toggle("仅字幕，不生成译音", isOn: $model.subtitlesOnly)
                        .accessibilityIdentifier("subtitlesOnly")
                    if !model.targetLanguage.defaultSpeech && !model.bidirectional {
                        Text("本版\(model.targetLanguage.name)暂仅提供字幕，已自动采用不生成译音的模式。")
                            .font(.footnote).foregroundColor(.secondary)
                    } else {
                        Text(model.subtitlesOnly ? "服务端仅返回字幕，不生成翻译语音。" : "服务端返回双语字幕和翻译语音。关闭底部扬声器只静音；要停止生成译音，请在这里启用仅字幕。")
                            .font(.footnote).foregroundColor(.secondary)
                    }
                }
                if model.provider == .bailian {
                    Section("常用译入语言") {
                        Button("译为英语") { model.selectTarget("en") }
                        Button("译为中文") { model.selectTarget("zh") }
                    }
                } else {
                Section("常用方向") {
                    Button { model.selectPair(source: "zh", target: "en") } label: {
                        Label("中文译为英语", systemImage: "person.2")
                    }.accessibilityIdentifier("faceToFaceScene")
                    Button { model.selectPair(source: "en", target: "zh") } label: {
                        Label("英语译为中文", systemImage: "person.2")
                    }
                    Button { model.selectBidirectional() } label: {
                        Label("中英免切换互译（测试）", systemImage: "arrow.triangle.2.circlepath")
                    }
                    if model.bidirectional {
                        Text("中英自动互译仍在测试，若服务报错，请选择明确的源语言和目标语言。")
                            .font(.footnote).foregroundColor(.secondary)
                    }
                }
                }
                Section { Text("切换语言或输出方式前需要结束当前会话。会记住上次选择的语言与字幕模式。")
                    .font(.footnote).foregroundColor(.secondary) }
            }.navigationTitle("语言与输出").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("完成") { showScenes = false } } }
        }.navigationViewStyle(.stack)
    }
    private var diagnostics: some View {
        NavigationView {
            Form {
                Section {
                    Button("测试本机麦克风（不联网）") { showDiagnostics = false; model.testMicrophone() }
                        .disabled(model.active).accessibilityIdentifier("localMicTest")
                    Text("先验证手机收音，再连接翻译服务。外放使用轮流收说避免回声；戴耳机可同时收听和说话。")
                        .font(.footnote).foregroundColor(.secondary)
                }
                Section("当前会话") {
                    LabeledContentCompat("服务商", model.provider.title)
                    LabeledContentCompat("译音采样率", model.provider == .bailian ? "24 kHz" : "16 kHz")
                    LabeledContentCompat("状态", model.status)
                    LabeledContentCompat("自动备用", model.automaticFallback ? "开启，最多切换一次" : "关闭")
                    LabeledContentCompat("已保存服务", model.configuredServices)
                    LabeledContentCompat("连接确认耗时", model.handshakeMilliseconds.map { "\($0) ms" } ?? "尚未就绪")
                    LabeledContentCompat("术语数量", String(model.glossaryCount))
                    if !model.latestFailure.isEmpty { Text(model.latestFailure).font(.footnote).textSelection(.enabled) }
                    LabeledContentCompat("翻译方向", model.translationTitle)
                    LabeledContentCompat("服务模式", model.producesSpeech ? "字幕与译音 S2S" : "仅字幕 S2T")
                    LabeledContentCompat("麦克风权限", model.microphonePermission)
                    LabeledContentCompat("录音方式", "原生 PCM 录音队列")
                    LabeledContentCompat("输入设备", model.inputDevice)
                    LabeledContentCompat("录音回调次数", String(model.inputBuffers))
                    LabeledContentCompat("收到麦克风字节", String(model.inputBytes))
                    LabeledContentCompat("麦克风采集包数", String(model.capturedPackets))
                    LabeledContentCompat("音频已发送包数", String(model.sentPackets))
                    LabeledContentCompat("外放静音包数", String(model.speakerSuppressedPackets))
                    LabeledContentCompat("收到译音字节", String(model.receivedAudioBytes))
                    LabeledContentCompat("播放设备", model.route)
                }
                Section { Text("每个完整音频包约 80 毫秒。诊断不含 API Key 或录音。当前版本需保持应用在前台。") }
            }.navigationTitle("连接诊断").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("完成") { showDiagnostics = false } } }
        }.navigationViewStyle(.stack)
    }
}
