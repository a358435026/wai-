import AVFoundation
import Combine
import Foundation
import UIKit

@MainActor
final class InterpreterModel: ObservableObject {
    enum Phase: Equatable { case idle, connecting, live, finishing }
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var source = CaptionLane()
    @Published private(set) var translation = CaptionLane()
    @Published private(set) var errorMessage: String?
    @Published private(set) var status = "准备就绪"
    @Published private(set) var playing = false
    @Published private(set) var route = "扬声器 / 耳机"
    @Published private(set) var inputLevel: Float = 0
    @Published private(set) var outputLevel: Float = 0
    @Published private(set) var inputBuffers = 0
    @Published private(set) var inputBytes = 0
    @Published private(set) var inputDevice = "尚未启动"
    @Published private(set) var localTest = false
    @Published private(set) var capturePausedForSpeaker = false
    @Published private(set) var capturedPackets = 0
    @Published private(set) var sentPackets = 0
    @Published private(set) var receivedAudioBytes = 0
    @Published private(set) var sourceCode = "zh"
    @Published private(set) var targetCode = "en"
    @Published private(set) var bidirectional = false
    @Published var subtitlesOnly = false {
        didSet { UserDefaults.standard.set(subtitlesOnly, forKey: "translation.subtitlesOnly") }
    }
    @Published var micMuted = false
    @Published var playbackEnabled = true {
        didSet { if !playbackEnabled { audio?.clearPlayback() } }
    }
    @Published private(set) var provider: TranslationProvider = .volcengine
    @Published var bailianHost = UserDefaults.standard.string(forKey: "bailian.host") ?? "" {
        didSet { UserDefaults.standard.set(bailianHost, forKey: "bailian.host") }
    }
    @Published var keySaved = false
    @Published var showSettings = false
    @Published var automaticFallback = UserDefaults.standard.object(forKey: "routing.automatic") as? Bool ?? true {
        didSet { UserDefaults.standard.set(automaticFallback, forKey: "routing.automatic") }
    }
    @Published var backupSource = UserDefaults.standard.string(forKey: "routing.source") ?? "zh" {
        didSet { UserDefaults.standard.set(backupSource, forKey: "routing.source") }
    }
    @Published var terminologyEnabled = UserDefaults.standard.bool(forKey: "terms.enabled") {
        didSet { UserDefaults.standard.set(terminologyEnabled, forKey: "terms.enabled") }
    }
    @Published var customTerms = UserDefaults.standard.string(forKey: "terms.text") ?? "" {
        didSet { UserDefaults.standard.set(customTerms, forKey: "terms.text") }
    }
    @Published var termsSource = UserDefaults.standard.string(forKey: "terms.source") ?? "zh" {
        didSet { UserDefaults.standard.set(termsSource, forKey: "terms.source") }
    }
    @Published var termsTarget = UserDefaults.standard.string(forKey: "terms.target") ?? "en" {
        didSet { UserDefaults.standard.set(termsTarget, forKey: "terms.target") }
    }
    @Published private(set) var switchNotice = ""
    @Published private(set) var latestFailure = ""
    @Published private(set) var firstTranslationDelay: Double?
    @Published private(set) var handshakeMilliseconds: Int?
    private var attempted: Set<TranslationProvider> = []
    private var health = TranslationHealth()
    private var connectionStarted = Date()
    private var latestSourceItem = ""
    private var pendingSwitchReason = ""
    var configuredServices: String { TranslationProvider.allCases.filter { KeychainStore.read(provider: $0) != nil }.map(\.title).joined(separator: "、") }
    var glossaryCount: Int { configuration.glossary.count }
    private var client: (any TranslationClient)?
    private var audio: AudioIO?
    private var streamContinuation: AsyncStream<Data>.Continuation?
    private var sendTask: Task<Void, Never>?
    private var connectionTask: Task<Void, Never>?
    private var deadlineTask: Task<Void, Never>?
    private var drainTask: Task<Void, Never>?
    private var captureWatchdog: Task<Void, Never>?
    private var lastCapture = Date()
    private var skipCurrentSpeech = false
    private var speakerHoldUntil = Date.distantPast
    var microphonePermission: String {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted: return "已授权"
        case .denied: return "未授权"
        default: return "尚未询问"
        }
    }
    private var observers: [NSObjectProtocol] = []
    private var generation = UUID()
    var active: Bool { phase != .idle }
    var sourceLanguage: ASTLanguage { provider == .bailian ? BailianLanguages.automatic : ASTLanguages.source(sourceCode)! }
    var targetLanguage: ASTLanguage { provider == .bailian ? BailianLanguages.target(targetCode)! : ASTLanguages.target(targetCode)! }
    var availableTargets: [ASTLanguage] { provider == .bailian ? BailianLanguages.targets : ASTLanguages.targets(for: sourceCode) }
    var translationTitle: String {
        bidirectional ? "中英互译（测试）" : "\(sourceLanguage.shortName) → \(targetLanguage.shortName)"
    }
    var producesSpeech: Bool { configuration.mode == .speechToSpeech }
    var canSwap: Bool { provider == .volcengine && !bidirectional && ASTLanguages.target(sourceCode) != nil }
    var configuration: ASTConfiguration {
        ASTConfiguration(source: provider == .bailian ? "bailian-auto" : bidirectional ? "zhen" : sourceCode,
                         target: bidirectional ? "zhen" : targetCode,
                         mode: provider == .bailian ? (subtitlesOnly || !targetLanguage.defaultSpeech ? .subtitles : .speechToSpeech) : bidirectional ? (subtitlesOnly ? .subtitles : .speechToSpeech)
                            : ASTLanguages.mode(target: targetCode, subtitlesOnly: subtitlesOnly),
                         glossary: (try? glossary()) ?? [:])
    }
    private func glossary() throws -> [String: String] {
        try TradeTerminology.combined(source: provider == .bailian ? "bailian-auto" : sourceCode,
            target: targetCode, enabled: terminologyEnabled, customSource: termsSource,
            customTarget: termsTarget, custom: customTerms)
    }
    var fallbackDescription: String {
        let current = configuration
        let next: TranslationProvider = provider == .bailian ? .volcengine : .bailian
        guard KeychainStore.read(provider: next) != nil else { return "备用\(next.title)尚未配置Key；仍可单独使用当前服务。" }
        guard let recipe = FailoverPolicy.configuration(for: next, current: current, automaticSource: backupSource) else {
            return "备用服务不支持当前方向或译音能力，本次不会自动降级或改变目标语言。"
        }
        if next == .volcengine {
            return "百炼自动识别；备用火山按\(ASTLanguages.source(recipe.source)?.name ?? recipe.source) → \(targetLanguage.name)。请确保备用源语言与你说的语言一致。"
        }
        return "当前服务连接失败、8秒未就绪或完整原文10秒无译文时，最多切换一次；先关闭旧会话，再启用备用。不会同时上传两家。"
    }
    func selectSource(_ code: String) {
        guard provider == .volcengine, !active, ASTLanguages.source(code) != nil else { return }
        bidirectional = false; sourceCode = code
        if ASTLanguages.validationError(source: code, target: targetCode) != nil {
            targetCode = code == "zh" ? "en" : "zh"
        }
        persistLanguages()
    }
    func selectTarget(_ code: String) {
        guard !active, availableTargets.contains(where: { $0.id == code }) else { return }
        bidirectional = false; targetCode = code; persistLanguages()
    }
    func selectPair(source: String, target: String) {
        guard provider == .volcengine, !active, ASTLanguages.validationError(source: source, target: target) == nil else { return }
        bidirectional = false; sourceCode = source; targetCode = target; persistLanguages()
    }
    func swapLanguages() {
        guard canSwap else { return }
        selectPair(source: targetCode, target: sourceCode)
    }
    func selectBidirectional() {
        guard provider == .volcengine, !active else { return }
        selectPair(source: "zh", target: "en"); bidirectional = true
    }
    private func persistLanguages() {
        UserDefaults.standard.set(sourceCode, forKey: "translation.\(provider.rawValue).source")
        UserDefaults.standard.set(targetCode, forKey: "translation.\(provider.rawValue).target")
    }
    func selectProvider(_ value: TranslationProvider) {
        guard !active, value != provider else { return }
        provider = value
        UserDefaults.standard.set(value.rawValue, forKey: "translation.provider")
        restoreLanguages(); keySaved = KeychainStore.read(provider: provider) != nil
        clearCaptions()
    }
    private func restoreLanguages() {
        let defaults = UserDefaults.standard
        if provider == .bailian {
            sourceCode = "bailian-auto"
            let saved = defaults.string(forKey: "translation.bailian.target") ?? "en"
            targetCode = BailianLanguages.target(saved) != nil ? saved : "en"
        } else {
            let input = defaults.string(forKey: "translation.volcengine.source") ?? defaults.string(forKey: "translation.source") ?? "zh"
            let output = defaults.string(forKey: "translation.volcengine.target") ?? defaults.string(forKey: "translation.target") ?? "en"
            sourceCode = ASTLanguages.validationError(source: input, target: output) == nil ? input : "zh"
            targetCode = ASTLanguages.validationError(source: input, target: output) == nil ? output : "en"
        }
        bidirectional = false
    }
    init() {
        provider = TranslationProvider(rawValue: UserDefaults.standard.string(forKey: "translation.provider") ?? "") ?? .volcengine
        restoreLanguages()
        keySaved = KeychainStore.read(provider: provider) != nil
        subtitlesOnly = UserDefaults.standard.bool(forKey: "translation.subtitlesOnly")
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-reset-languages") {
            provider = .volcengine; sourceCode = "zh"; targetCode = "en"; subtitlesOnly = false
            keySaved = KeychainStore.read(provider: provider) != nil
        }
        if ProcessInfo.processInfo.arguments.contains("--ui-auth-error") {
            errorMessage = ConnectionFailure(provider: .volcengine, status: 401).localizedDescription
            status = "连接已停止"
        }
        if ProcessInfo.processInfo.arguments.contains("--ui-speaking") {
            playing = true; outputLevel = 0.7
        }
        if ProcessInfo.processInfo.arguments.contains("--ui-captions") {
            source.append("您好，我想了解这款电动车的续航和交货时间。"); source.end()
            translation.append("Hello, I would like to know the range and delivery time of this electric bike."); translation.end()
        }
        #endif
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification,
                                             object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.active else { return }
                self.fail("音频被来电或其他应用中断。请返回后重新开始。")
            }
        })
        observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification,
                                             object: nil, queue: .main) { [weak self] notification in
            let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            Task { @MainActor in
                guard let self else { return }
                self.route = self.audio?.routeName ?? "扬声器 / 耳机"
                if self.active && reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue {
                    self.fail("耳机或音频设备已断开。请确认播放设备后重新开始。")
                }
            }
        })
        observers.append(center.addObserver(forName: UIApplication.didEnterBackgroundNotification,
                                             object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.active else { return }
                self.cleanup()
                self.status = "已停止：应用进入后台"
            }
        })
    }
    deinit { observers.forEach { NotificationCenter.default.removeObserver($0) } }

    func saveKey(_ value: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard trimmed.unicodeScalars.allSatisfy({ $0.value > 32 && $0.value < 127 }), trimmed.count >= 16 else {
            throw BailianError("请只粘贴完整Key，不要附带说明文字、换行或空格。")
        }
        if provider == .bailian {
            bailianHost = try BailianWire.normalizedHost(bailianHost)
            guard trimmed.hasPrefix("sk-"), !trimmed.contains("*") else { throw BailianError("请填写完整的百炼 API Key。") }
        }
        try KeychainStore.save(trimmed, provider: provider)
        keySaved = true
    }
    func deleteKey() throws { try KeychainStore.delete(provider: provider); keySaved = false }
    func clearCaptions() { source = CaptionLane(); translation = CaptionLane(); errorMessage = nil }
    func interruptPlayback() { skipCurrentSpeech = true; audio?.clearPlayback() }

    // This test uses the exact recording path as a real session, without opening
    // a WebSocket or needing a key. It remains active until the user stops it.
    func testMicrophone() {
        guard !active else { return }
        resetAudioStats(); clearCaptions(); localTest = true
        phase = .connecting; status = "正在启动本机麦克风测试"
        let run = UUID(); generation = run
        connectionTask = Task { [weak self] in
            guard let self else { return }
            let allowed = await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { continuation.resume(returning: $0) }
            }
            guard self.generation == run else { return }
            guard allowed else { self.fail("麦克风权限被拒绝。请在 iPhone 设置中允许随声同传使用麦克风。"); return }
            self.prepareAudio()
            guard self.generation == run else { return }
            for _ in 0..<60 {
                if self.capturedPackets > 0 { break }
                do { try await Task.sleep(nanoseconds: 100_000_000) } catch { return }
                guard self.generation == run else { return }
            }
            guard self.capturedPackets > 0 else { self.fail(self.captureFailureDescription); return }
            self.phase = .live; self.status = "本机收音测试中 · 不联网"
            UIApplication.shared.isIdleTimerDisabled = true
        }
    }
    private var captureFailureDescription: String {
        "麦克风\(microphonePermission)，但录音队列\(inputBuffers == 0 ? "没有返回缓冲" : "没有产生有效 PCM 包")。输入：\(inputDevice)；回调 \(inputBuffers) 次，\(inputBytes) 字节。请打开连接诊断查看。"
    }
    private func resetAudioStats() {
        capturedPackets = 0; sentPackets = 0; receivedAudioBytes = 0
        inputBuffers = 0; inputBytes = 0; inputLevel = 0; outputLevel = 0
        inputDevice = "尚未启动"; capturePausedForSpeaker = false
        speakerHoldUntil = .distantPast
    }

    func start() { startSession(resuming: false) }
    private func startSession(resuming: Bool) {
        guard phase == .idle else { return }
        if !resuming {
            attempted = []; switchNotice = ""; latestFailure = ""; pendingSwitchReason = ""
        }
        attempted.insert(provider)
        do { _ = try glossary() } catch { errorMessage = error.localizedDescription; return }
        health = TranslationHealth(); latestSourceItem = ""; firstTranslationDelay = nil; handshakeMilliseconds = nil
        if provider == .volcengine, !bidirectional, let error = ASTLanguages.validationError(source: sourceCode, target: targetCode) {
            errorMessage = error; return
        }
        if provider == .bailian {
            do { bailianHost = try BailianWire.normalizedHost(bailianHost) }
            catch { errorMessage = error.localizedDescription; showSettings = true; return }
        }
        guard let key = KeychainStore.read(provider: provider), !key.isEmpty else { showSettings = true; return }
        if !resuming { clearCaptions() }
        else { source.end(); translation.end(); errorMessage = nil }
        micMuted = false
        resetAudioStats(); localTest = false; skipCurrentSpeech = false
        phase = .connecting; status = "正在申请麦克风并连接"
        let run = UUID(); generation = run
        connectionTask = Task { [weak self] in
            guard let self else { return }
            let allowed = await withCheckedContinuation { continuation in
                if #available(iOS 17.0, *) {
                    AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
                } else {
                    AVAudioSession.sharedInstance().requestRecordPermission { continuation.resume(returning: $0) }
                }
            }
            guard self.generation == run && !Task.isCancelled else { return }
            guard allowed else { self.fail("麦克风权限未开启。请在 iPhone 设置中允许随声同传使用麦克风。"); return }
            self.status = "正在准备麦克风"
            self.prepareAudio()
            guard self.generation == run else { return }
            // Warm up voice processing before asking the server to wait for packets.
            for _ in 0..<60 {
                if self.capturedPackets > 0 { break }
                do { try await Task.sleep(nanoseconds: 100_000_000) } catch { return }
                guard self.generation == run else { return }
            }
            guard self.capturedPackets > 0 else {
                self.fail(self.captureFailureDescription); return
            }
            self.status = "正在连接\(self.provider.title)"
            self.connectionStarted = Date()
            let onResponse: (ASTResponse) -> Void = { [weak self] response in
                guard let self, self.generation == run else { return }
                self.receive(response)
            }
            let onError: (Error) -> Void = { [weak self] error in
                guard let self, self.generation == run else { return }
                self.serviceFailed(self.describe(error))
            }
            let client: any TranslationClient
            do {
                if self.provider == .bailian {
                    client = try BailianClient(host: self.bailianHost, onResponse: onResponse, onError: onError)
                } else { client = ASTClient(onResponse: onResponse, onError: onError) }
            } catch { self.fail(error.localizedDescription); return }
            self.client = client
            self.deadlineTask = Task { [weak self] in
                do { try await Task.sleep(nanoseconds: self?.automaticFallback == true ? 8_000_000_000 : 20_000_000_000) } catch { return }
                guard let self, self.generation == run, self.phase == .connecting else { return }
                self.serviceFailed("\(self.provider.title)连接超时，尚未确认同传会话。")
            }
            do { try await client.connect(key: key, configuration: self.configuration) }
            catch { if self.generation == run && !Task.isCancelled { self.serviceFailed(self.describe(error)) } }
        }
    }

    private func receive(_ response: ASTResponse) {
        if ![0, 21000, 20000000].contains(response.statusCode) || response.event == 153 {
            serviceFailed("\(provider.title)服务错误 \(response.statusCode)：\(response.message.isEmpty ? "请检查服务权限、余额和语言配置。" : response.message)")
            return
        }
        switch response.event {
        case 150:
            guard phase == .connecting else { return }
            deadlineTask?.cancel()
            handshakeMilliseconds = Int(Date().timeIntervalSince(connectionStarted) * 1000)
            persistLanguages()
            if automaticFallback { UserDefaults.standard.set(provider.rawValue, forKey: "translation.provider") }
            if !pendingSwitchReason.isEmpty { switchNotice = pendingSwitchReason + " 已连接；切换期间请重说最后一句。" }
            phase = .live; status = "正在聆听"
            lastCapture = Date()
            UIApplication.shared.isIdleTimerDisabled = true
        case 660:
            if latestSourceItem != response.captionID { latestSourceItem = response.captionID; health.sourceBegan() }
            source.set(id: response.captionID, text: response.text, final: response.final)
            if response.final && !response.text.isEmpty { health.sourceCompleted(at: Date()) }
        case 661:
            translation.set(id: response.captionID, text: response.text, final: response.final)
            if !response.text.isEmpty { health.translated(at: Date()); firstTranslationDelay = health.lastLatency }
        case 650: source.begin(); health.sourceBegan()
        case 651: source.append(response.text)
        case 652:
            source.end()
            if source.captions.last?.text.isEmpty == false { health.sourceCompleted(at: Date()) }
        case 653: translation.begin()
        case 654:
            translation.append(response.text)
            if !response.text.isEmpty { health.translated(at: Date()); firstTranslationDelay = health.lastLatency }
        case 655: translation.end()
        case 350: skipCurrentSpeech = false
        case 352:
            receivedAudioBytes += response.audio.count
            guard producesSpeech && playbackEnabled && !skipCurrentSpeech else { return }
            do { try audio?.play(response.audio) } catch { fail(error.localizedDescription) }
        case 152, 151:
            finishReceiving()
        default: break // Includes usage, sentence boundaries, and future events.
        }
    }

    private func prepareAudio() {
        let run = generation
        let stream = AsyncStream<Data>(bufferingPolicy: .bufferingOldest(16)) { self.streamContinuation = $0 }
        let continuation = streamContinuation!
        let audio = AudioIO(outputRate: provider.outputRate)
        self.audio = audio
        audio.onPlaybackChanged = { [weak self] value in
            guard let self else { return }
            self.playing = value
            if self.audio?.isSpeaker == true { self.speakerHoldUntil = value ? .distantFuture : Date().addingTimeInterval(0.35) }
            if !value { self.outputLevel = 0 }
        }
        audio.onLevel = { [weak self] value in
            Task { @MainActor in
                guard let self, self.generation == run else { return }
                self.inputLevel = self.micMuted ? 0 : max(value, self.inputLevel * 0.55)
            }
        }
        audio.onOutputLevel = { [weak self] value in
            Task { @MainActor in
                guard let self, self.generation == run else { return }
                self.outputLevel = self.playing ? max(value, self.outputLevel * 0.65) : 0
            }
        }
        audio.onInputBuffer = { [weak self] bytes in
            Task { @MainActor in
                guard let self, self.generation == run else { return }
                self.inputBuffers += 1; self.inputBytes += bytes
            }
        }
        do {
            try audio.start(emit: { [weak self] data in
                if case .dropped = continuation.yield(data) {
                    Task { @MainActor in
                        guard let self, self.generation == run else { return }
                        self.serviceFailed("网络发送积压，已停止旧连接以避免延迟累积。")
                    }
                }
            }, failure: { [weak self] message in
                Task { @MainActor in
                    guard let self, self.generation == run else { return }
                    self.fail(message)
                }
            })
            route = audio.routeName
            inputDevice = audio.inputName.isEmpty ? "系统未提供输入路由" : audio.inputName
            sendTask = Task { [weak self] in
                do {
                    for await data in stream {
                        guard let self, self.generation == run, !Task.isCancelled else { break }
                        self.capturedPackets += 1
                        self.lastCapture = Date()
                        guard self.phase == .live || self.phase == .finishing, let client = self.client else { continue }
                        self.capturePausedForSpeaker = audio.isSpeaker && Date() < self.speakerHoldUntil
                        let packet = (self.micMuted || self.capturePausedForSpeaker) ? Data(repeating: 0, count: data.count) : data
                        try await client.sendAudio(packet)
                        self.sentPackets += 1
                    }
                } catch {
                    guard let self, self.generation == run, !Task.isCancelled else { return }
                    self.serviceFailed(self.describe(error))
                }
            }
            captureWatchdog = Task { [weak self] in
                while !Task.isCancelled {
                    do { try await Task.sleep(nanoseconds: 1_000_000_000) } catch { return }
                    guard let self, self.generation == run else { return }
                    if self.phase == .live && !self.localTest && self.automaticFallback && self.health.stalled(at: Date(), suspended: self.micMuted || self.capturePausedForSpeaker || self.playing) {
                        self.serviceFailed("完整原文已返回，但等待译文超过10秒。"); return
                    }
                    if self.phase == .live && Date().timeIntervalSince(self.lastCapture) > 3 {
                        self.fail("麦克风音频流已中断，已结束连接。请检查音频设备后重新开始。"); return
                    }
                }
            }
        } catch { fail(error.localizedDescription) }
    }

    func stop() {
        guard phase != .idle else { return }
        if localTest { cleanup(); status = "本机收音测试已结束"; return }
        if phase == .connecting { cleanup(); status = "已取消连接"; return }
        guard phase == .live else { return }
        phase = .finishing; status = "正在完成最后一句"
        audio?.stopCapture(); streamContinuation?.finish()
        let run = generation
        let sender = sendTask
        deadlineTask = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 12_000_000_000) } catch { return }
            guard let self, self.generation == run else { return }
            self.fail("服务未及时完成收尾，本次连接已关闭。已显示的字幕保留。")
        }
        Task { [weak self] in
            await sender?.value
            guard let self, self.generation == run else { return }
            do { try await self.client?.finish() } catch { self.fail(self.describe(error)); return }
        }
    }
    private func finishReceiving() {
        deadlineTask?.cancel()
        phase = .finishing; status = "正在播完译音"
        audio?.stopCapture(); streamContinuation?.finish()
        sendTask?.cancel()
        client?.disconnect()
        let run = generation
        drainTask = Task { [weak self] in
            for _ in 0..<220 {
                guard let self, self.generation == run else { return }
                if self.audio?.isPlaying != true { break }
                do { try await Task.sleep(nanoseconds: 100_000_000) } catch { return }
            }
            guard let self, self.generation == run else { return }
            self.source.end(); self.translation.end()
            self.cleanup(); self.status = "本次同传已结束"
        }
    }
    private func serviceFailed(_ message: String) {
        latestFailure = message
        guard automaticFallback, !localTest, phase != .finishing,
              let next = FailoverPolicy.destination(current: provider, tried: attempted,
                  configured: Set(TranslationProvider.allCases.filter { KeychainStore.read(provider: $0) != nil })),
              let recipe = FailoverPolicy.configuration(for: next, current: configuration, automaticSource: backupSource) else {
            fail(message); return
        }
        if next == .bailian, (try? BailianWire.normalizedHost(bailianHost)) == nil {
            fail(message + " 备用百炼Host尚未配置，未自动切换。"); return
        }
        let old = provider
        cleanup() // Invalidate all old callbacks and close socket/audio before creating another provider.
        provider = next; sourceCode = next == .bailian ? "bailian-auto" : recipe.source
        targetCode = recipe.target; bidirectional = false
        keySaved = KeychainStore.read(provider: next) != nil
        pendingSwitchReason = "\(old.title)未就绪或响应过慢，已切换\(next.title)。"
        switchNotice = pendingSwitchReason
        startSession(resuming: true)
    }
    func fail(_ message: String) {
        cleanup(); errorMessage = message; status = "连接已停止"
    }
    private func cleanup() {
        generation = UUID()
        deadlineTask?.cancel(); drainTask?.cancel(); connectionTask?.cancel(); captureWatchdog?.cancel()
        audio?.shutdown(); audio = nil
        streamContinuation?.finish(); streamContinuation = nil
        sendTask?.cancel(); sendTask = nil
        client?.disconnect(); client = nil
        playing = false; phase = .idle; micMuted = false; inputLevel = 0; outputLevel = 0
        capturePausedForSpeaker = false; localTest = false
        UIApplication.shared.isIdleTimerDisabled = false
    }
    private func describe(_ error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return ConnectionFailure(provider: provider, code: nsError.code).localizedDescription
        }
        return error.localizedDescription
    }
}
