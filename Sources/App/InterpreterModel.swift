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
    @Published private(set) var capturedPackets = 0
    @Published private(set) var sentPackets = 0
    @Published private(set) var receivedAudioBytes = 0
    @Published var direction = 0
    @Published var micMuted = false
    @Published var playbackEnabled = true {
        didSet { if !playbackEnabled { audio?.clearPlayback() } }
    }
    @Published var keySaved = KeychainStore.read() != nil
    @Published var showSettings = false
    private var client: ASTClient?
    private var audio: AudioIO?
    private var streamContinuation: AsyncStream<Data>.Continuation?
    private var sendTask: Task<Void, Never>?
    private var connectionTask: Task<Void, Never>?
    private var deadlineTask: Task<Void, Never>?
    private var drainTask: Task<Void, Never>?
    private var captureWatchdog: Task<Void, Never>?
    private var lastCapture = Date()
    private var skipCurrentSpeech = false
    private var observers: [NSObjectProtocol] = []
    private var generation = UUID()
    let directions = ["中文 → English", "English → 中文", "中英自动互译（测试）"]
    var active: Bool { phase != .idle }
    var configuration: ASTConfiguration {
        switch direction {
        case 1: return ASTConfiguration(source: "en", target: "zh")
        case 2: return ASTConfiguration(source: "zhen", target: "zhen")
        default: return ASTConfiguration()
        }
    }

    init() {
        #if DEBUG
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
        try KeychainStore.save(trimmed)
        keySaved = true
    }
    func deleteKey() throws { try KeychainStore.delete(); keySaved = false }
    func clearCaptions() { source = CaptionLane(); translation = CaptionLane(); errorMessage = nil }
    func interruptPlayback() { skipCurrentSpeech = true; audio?.clearPlayback() }

    func start() {
        guard phase == .idle else { return }
        guard let key = KeychainStore.read(), !key.isEmpty else { showSettings = true; return }
        clearCaptions(); micMuted = false
        capturedPackets = 0; sentPackets = 0; receivedAudioBytes = 0; inputLevel = 0; skipCurrentSpeech = false
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
            for _ in 0..<40 {
                if self.capturedPackets > 0 { break }
                do { try await Task.sleep(nanoseconds: 100_000_000) } catch { return }
                guard self.generation == run else { return }
            }
            guard self.capturedPackets > 0 else {
                self.fail("麦克风未输出音频。请检查权限和音频设备，然后重新开始。"); return
            }
            self.status = "正在连接火山引擎"
            let client = ASTClient(onResponse: { [weak self] response in
                guard let self, self.generation == run else { return }
                self.receive(response)
            }, onError: { [weak self] error in
                guard let self, self.generation == run else { return }
                self.fail(self.describe(error))
            })
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
        case 650: source.begin()
        case 651: source.append(response.text)
        case 652: source.end()
        case 653: translation.begin()
        case 654: translation.append(response.text)
        case 655: translation.end()
        case 350: skipCurrentSpeech = false
        case 352:
            receivedAudioBytes += response.audio.count
            guard playbackEnabled && !skipCurrentSpeech else { return }
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
        let audio = AudioIO()
        self.audio = audio
        audio.onPlaybackChanged = { [weak self] value in self?.playing = value }
        audio.onLevel = { [weak self] value in
            Task { @MainActor in
                guard let self, self.generation == run else { return }
                self.inputLevel = self.micMuted ? 0 : value
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
            sendTask = Task { [weak self] in
                do {
                    for await data in stream {
                        guard let self, self.generation == run, !Task.isCancelled else { break }
                        self.capturedPackets += 1
                        self.lastCapture = Date()
                        guard self.phase == .live || self.phase == .finishing, let client = self.client else { continue }
                        let packet = self.micMuted ? Data(repeating: 0, count: data.count) : data
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
        playing = false; phase = .idle; micMuted = false; inputLevel = 0
        UIApplication.shared.isIdleTimerDisabled = false
    }
    private func describe(_ error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return "网络连接失败（\(nsError.code)）。请检查网络，以及火山引擎 API Key、余额和同传服务权限。"
        }
        return error.localizedDescription
    }
}
