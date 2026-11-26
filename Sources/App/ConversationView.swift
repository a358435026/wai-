import SwiftUI

// Own visual tokens; no assets or executable code from the reference app.
enum VoiceTheme {
    static let ink = Color(red: 0.13, green: 0.12, blue: 0.19)
    static let muted = Color(red: 0.48, green: 0.44, blue: 0.51)
    static let accent = Color(red: 0.40, green: 0.29, blue: 0.67)
    static let rose = Color(red: 0.98, green: 0.83, blue: 0.88)
    static let lilac = Color(red: 0.87, green: 0.84, blue: 0.97)
    static let sky = Color(red: 0.83, green: 0.94, blue: 0.99)
    static let mint = Color(red: 0.88, green: 0.96, blue: 0.95)
    static let spacing: CGFloat = 24
    static let control: CGFloat = 70
    static let orb: CGFloat = 240
    static let copy: CGFloat = 23
    static let capsule: CGFloat = 22
}

@MainActor
struct ContentView: View {
    @StateObject private var model = InterpreterModel()
    @State private var showCaptions = true
    @State private var showScenes = false
    @State private var showDiagnostics = false
    @State private var scene = "面对面对话"
    private var hasCaptions: Bool {
        model.source.captions.contains { !$0.text.isEmpty } || model.translation.captions.contains { !$0.text.isEmpty }
    }
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: VoiceTheme.spacing) {
                toolbar.padding(.top, 12)
                if showCaptions && hasCaptions { transcript }
                else { listeningArea }
                if let error = model.errorMessage {
                    Text(error).font(.footnote).foregroundColor(.red)
                        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.65), in: RoundedRectangle(cornerRadius: VoiceTheme.capsule))
                        .accessibilityIdentifier("errorMessage")
                }
                statusArea
                controls
                Text("随声同传 · AI 译音").font(.caption).foregroundColor(VoiceTheme.muted)
                    .padding(.bottom, 10)
            }
            .padding(.horizontal, VoiceTheme.spacing)
            .frame(maxWidth: 700).frame(width: geometry.size.width, height: geometry.size.height)
        }
        .foregroundColor(VoiceTheme.ink)
        .background(background.ignoresSafeArea())
        .sheet(isPresented: $model.showSettings) { SettingsView(model: model) }
        .sheet(isPresented: $showScenes) { sceneSheet }
        .sheet(isPresented: $showDiagnostics) { diagnostics }
        .tint(VoiceTheme.accent)
    }
    private var background: some View {
        ZStack {
            LinearGradient(colors: [VoiceTheme.rose, VoiceTheme.lilac, VoiceTheme.sky], startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [VoiceTheme.mint.opacity(0.6), .clear], center: .bottomLeading, startRadius: 0, endRadius: 500)
        }
    }
    private var toolbar: some View {
        HStack {
            Menu {
                Button { model.showSettings = true } label: { Label("设置", systemImage: "slider.horizontal.3") }.disabled(model.active)
                Button { model.clearCaptions() } label: { Label("清空字幕", systemImage: "trash") }.disabled(model.active)
                Button { showDiagnostics = true } label: { Label("连接诊断", systemImage: "waveform.path.ecg") }
            } label: {
                Image(systemName: "ellipsis").font(.title2).frame(width: 40, height: 44)
            }.accessibilityLabel("更多选项")
            Spacer(minLength: 4)
            Button { showScenes = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.grid.2x2.fill")
                    Text(scene).font(.headline)
                }.padding(.horizontal, 18).padding(.vertical, 13)
                    .background(Color.white.opacity(0.30), in: Capsule())
            }.disabled(model.active).accessibilityIdentifier("scenePicker")
            Spacer(minLength: 4)
            Button { showCaptions.toggle() } label: {
                Image(systemName: showCaptions ? "captions.bubble.fill" : "captions.bubble")
                    .font(.title2).frame(width: 40, height: 44)
            }.accessibilityLabel(showCaptions ? "隐藏字幕" : "显示字幕")
        }
    }
    private var listeningArea: some View {
        VStack(spacing: VoiceTheme.spacing) {
            Spacer(minLength: 0)
            VoiceOrb(level: model.inputLevel, active: model.phase == .live, playing: model.playing)
                .frame(width: VoiceTheme.orb, height: VoiceTheme.orb)
                .accessibilityLabel(model.active ? "语音会话进行中" : "同声传译待机")
            VStack(spacing: 10) {
                Text("随声同传").font(.title2.weight(.semibold))
                Text(model.directions[model.direction]).font(.subheadline).foregroundColor(VoiceTheme.muted)
            }
            Spacer(minLength: 0)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private var transcript: some View {
        ScrollViewReader { reader in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: VoiceTheme.spacing) {
                    ForEach(0..<max(model.source.captions.count, model.translation.captions.count), id: \.self) { index in
                        VStack(alignment: .leading, spacing: 14) {
                            if index < model.source.captions.count {
                                Text(model.source.captions[index].text)
                                    .foregroundColor(VoiceTheme.muted).font(.system(size: VoiceTheme.copy - 3))
                                    .textSelection(.enabled)
                            }
                            if index < model.translation.captions.count {
                                Text(model.translation.captions[index].text)
                                    .font(.system(size: VoiceTheme.copy, weight: .medium))
                                    .textSelection(.enabled)
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
                    }
                    Color.clear.frame(height: 1).id("latest")
                }.padding(.horizontal, 12).padding(.vertical, VoiceTheme.spacing)
            }
            .onChange(of: model.translation.captions) { _ in reader.scrollTo("latest", anchor: .bottom) }
            .onChange(of: model.source.captions) { _ in reader.scrollTo("latest", anchor: .bottom) }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private var statusArea: some View {
        VStack(spacing: 9) {
            if model.phase == .connecting || model.phase == .finishing { ProgressView() }
            else if model.phase == .live {
                HStack(alignment: .center, spacing: 5) {
                    ForEach(0..<5) { i in
                        Capsule().fill(VoiceTheme.accent.opacity(0.65))
                            .frame(width: 4, height: CGFloat(8 + model.inputLevel * Float(i % 3 + 1) * 24))
                    }
                }.frame(height: 36).animation(.easeOut(duration: 0.12), value: model.inputLevel)
            }
            Button {
                if model.playing { model.interruptPlayback() }
            } label: {
                Text(statusTitle).font(.headline).foregroundColor(VoiceTheme.muted)
            }.disabled(!model.playing).accessibilityIdentifier("voiceStatus")
            Text(model.active ? model.route : "点击下方开始，音频将发送至火山引擎")
                .font(.caption).foregroundColor(VoiceTheme.muted).multilineTextAlignment(.center)
            if model.micMuted && model.active {
                Text("麦克风已静音，会话仍可能计费").font(.caption).foregroundColor(VoiceTheme.muted)
            }
        }.frame(minHeight: 74)
    }
    private var statusTitle: String {
        if model.playing { return "正在播报 · 点击打断" }
        if model.phase == .live { return model.micMuted ? "麦克风已静音" : "请开始说话" }
        if !model.keySaved { return "先配置 API Key" }
        return model.status
    }
    private var controls: some View {
        HStack(spacing: VoiceTheme.spacing) {
            circleButton(icon: model.micMuted ? "mic.slash.fill" : "mic.fill",
                         label: model.micMuted ? "打开麦克风" : "麦克风静音", selected: !model.micMuted) {
                model.micMuted.toggle()
            }.disabled(model.phase != .live)
            circleButton(icon: model.playbackEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill",
                         label: model.playbackEnabled ? "关闭译音" : "开启译音", selected: model.playbackEnabled) {
                model.playbackEnabled.toggle()
            }
            Button { if model.active { model.stop() } else { model.start() } } label: {
                Image(systemName: model.active ? "xmark" : "waveform")
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundColor(model.active ? .red : .white)
                    .frame(width: VoiceTheme.control, height: VoiceTheme.control)
                    .background(model.active ? Color.white.opacity(0.55) : VoiceTheme.accent, in: Circle())
            }.accessibilityLabel(model.active ? "结束同传" : "开始同传")
                .accessibilityIdentifier("mainAction").disabled(model.phase == .finishing)
        }.padding(.vertical, 8)
    }
    private func circleButton(icon: String, label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 26))
                .frame(width: VoiceTheme.control, height: VoiceTheme.control)
                .background(Color.white.opacity(selected ? 0.80 : 0.30), in: Circle())
        }.accessibilityLabel(label)
    }
    private var sceneSheet: some View {
        NavigationView {
            Form {
                Section("使用场景") {
                    Button { scene = "面对面对话"; model.direction = 2 } label: {
                        Label("面对面对话 · 中英自动互译", systemImage: "person.2")
                    }.accessibilityIdentifier("faceToFaceScene")
                    Button { scene = "会议听译"; if model.direction == 2 { model.direction = 0 } } label: {
                        Label("会议听译 · 单向连续翻译", systemImage: "person.3")
                    }
                }
                Section("翻译方向") {
                    Picker("方向", selection: $model.direction) {
                        ForEach(model.directions.indices, id: \.self) { Text(model.directions[$0]).tag($0) }
                    }
                    Text("切换场景或方向前需要结束当前会话。会议听译使用手机麦克风收音。")
                        .font(.footnote).foregroundColor(.secondary)
                }
            }.navigationTitle("对话场景").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("完成") { showScenes = false } } }
        }.navigationViewStyle(.stack)
    }
    private var diagnostics: some View {
        NavigationView {
            Form {
                Section("当前会话") {
                    LabeledContentCompat("状态", model.status)
                    LabeledContentCompat("麦克风采集包数", String(model.capturedPackets))
                    LabeledContentCompat("音频已发送包数", String(model.sentPackets))
                    LabeledContentCompat("收到译音字节", String(model.receivedAudioBytes))
                    LabeledContentCompat("播放设备", model.route)
                }
                Section { Text("每个完整音频包约 80 毫秒。诊断不含 API Key 或录音。当前版本需保持应用在前台。") }
            }.navigationTitle("连接诊断").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("完成") { showDiagnostics = false } } }
        }.navigationViewStyle(.stack)
    }
}

private struct LabeledContentCompat: View {
    let label: String
    let value: String
    init(_ label: String, _ value: String) { self.label = label; self.value = value }
    var body: some View { HStack { Text(label); Spacer(); Text(value).foregroundColor(.secondary) } }
}

private struct VoiceOrb: View {
    let level: Float
    let active: Bool
    let playing: Bool
    @State private var breathe = false
    var body: some View {
        ZStack {
            Circle().fill(VoiceTheme.lilac.opacity(0.25)).blur(radius: 24)
                .scaleEffect(breathe ? 1.13 : 0.93)
            Circle().fill(LinearGradient(colors: [VoiceTheme.rose, VoiceTheme.lilac, VoiceTheme.sky],
                                        startPoint: .bottomLeading, endPoint: .topTrailing))
            Circle().fill(RadialGradient(colors: [VoiceTheme.accent.opacity(0.50), .clear],
                                        center: breathe ? .topTrailing : .topLeading, startRadius: 0, endRadius: 220))
                .blur(radius: 18).clipShape(Circle())
            Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
        }
        .scaleEffect(active ? 1 + CGFloat(level) * 0.08 : 1)
        .rotationEffect(.degrees(breathe ? 12 : -12))
        .animation(.easeInOut(duration: 0.18), value: level)
        .onAppear { withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) { breathe = true } }
    }
}
