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
        ASTConfiguration(source: bidirectional ? "zhen" : sourceCode,
                         target: bidirectional ? "zhen" : targetCode,
                         mode: provider == .bailian ? (subtitlesOnly || !targetLanguage.defaultSpeech ? .subtitles : .speechToSpeech) : bidirectional ? (subtitlesOnly ? .subtitles : .speechToSpeech)
                            : ASTLanguages.mode(target: targetCode, subtitlesOnly: subtitlesOnly))
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

    func start() {
        guard phase == .idle else { return }
        if provider == .volcengine, !bidirectional, let error = ASTLanguages.validationError(source: sourceCode, target: targetCode) {
            errorMessage = error; return
        }
        if provider == .bailian {
            do { bailianHost = try BailianWire.normalizedHost(bailianHost) }
            catch { errorMessage = error.localizedDescription; showSettings = true; return }
        }
        guard let key = KeychainStore.read(provider: provider), !key.isEmpty else { showSettings = true; return }
        clearCaptions(); micMuted = false
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
            let onResponse: (ASTResponse) -> Void = { [weak self] response in
                guard let self, self.generation == run else { return }
                self.receive(response)
            }
            let onError: (Error) -> Void = { [weak self] error in
                guard let self, self.generation == run else { return }
                self.fail(self.describe(error))
            }
            let client: any TranslationClient
            do {
                if self.provider == .bailian {
                    client = try BailianClient(host: self.bailianHost, onResponse: onResponse, onError: onError)
                } else { client = ASTClient(onResponse: onResponse, onError: onError) }
            } catch { self.fail(error.localizedDescription); return }
            self.client = client
            self.deadlineTask = Task { [weak self] in
                do { try await Task.sleep(nanoseconds: 20_000_000_000) } catch { return }
                guard let self, self.generation == run, self.phase == .connecting else { return }
                self.fail("连接超时。请检查网络、API Key 和同声传译服务是否已开通。")
            }
            do { try await client.connect(key: key, configuration: self.configuration) }
            catch { if self.generation == run && !Task.isCancelled { self.fail(self.describe(error)) } }
        }
    }

    private func receive(_ response: ASTResponse) {
        if ![0, 21000, 20000000].contains(response.statusCode) || response.event == 153 {
            fail("服务错误 \(response.statusCode)：\(response.message.isEmpty ? "请检查服务权限、余额和语言配置。" : response.message)")
            return
        }
        switch response.event {
        case 150:
            guard phase == .connecting else { return }
            deadlineTask?.cancel()
            phase = .live; status = "正在聆听"
            lastCapture = Date()
            UIApplication.shared.isIdleTimerDisabled = true
        case 660: source.set(id: response.captionID, text: response.text, final: response.final)
        case 661: translation.set(id: response.captionID, text: response.text, final: response.final)
        case 650: source.begin()
        case 651: source.append(response.text)
        case 652: source.end()
        case 653: translation.begin()
        case 654: translation.append(response.text)
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
                        self.fail("网络发送积压，已停止同传以避免译音延迟。请检查网络后重试。")
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
                    self.fail(self.describe(error))
                }
            }
            captureWatchdog = Task { [weak self] in
                while !Task.isCancelled {
                    do { try await Task.sleep(nanoseconds: 1_000_000_000) } catch { return }
                    guard let self, self.generation == run else { return }
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
            return "网络连接失败（\(nsError.code)）。请检查网络，以及\(provider.title) API Key、余额和同传服务权限。"
        }
        return error.localizedDescription
    }
}
