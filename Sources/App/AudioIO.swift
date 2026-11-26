import AVFoundation
import Foundation

enum AudioError: LocalizedError {
    case format, noInput, playbackOverflow
    case queue(String, Int32)
    var errorDescription: String? {
        switch self {
        case .format: return "无法建立音频格式，请重新开始或更换音频设备。"
        case .noInput: return "系统没有可用的音频输入设备。请重新连接耳机或使用手机麦克风。"
        case let .queue(operation, code): return "\(operation)失败（\(code)）。麦克风已授权不代表录音已启动，请查看连接诊断。"
        case .playbackOverflow: return "译音积压超过 20 秒，已停止同传。请检查网络后重新开始。"
        }
    }
}

@MainActor
final class AudioIO {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var capture: PCMInputQueue?
    private var meterInstalled = false
    var onLevel: (@Sendable (Float) -> Void)?
    var onOutputLevel: (@Sendable (Float) -> Void)?
    var onInputBuffer: (@Sendable (Int) -> Void)?
    private var playbackGeneration = UUID()
    private var pendingPCM = Data()
    private(set) var pendingSamples = 0
    private let outputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000,
                                             channels: 1, interleaved: false)!
    var onPlaybackChanged: ((Bool) -> Void)?
    var isPlaying: Bool { pendingSamples > 0 }

    func start(emit: @escaping @Sendable (Data) -> Void,
               failure: @escaping @Sendable (String) -> Void) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default,
                                options: [.defaultToSpeaker, .allowBluetooth])
        try session.setPreferredIOBufferDuration(0.02)
        try session.setActive(true)
        guard session.isInputAvailable else { throw AudioError.noInput }
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: outputFormat)
        let reportOutput = onOutputLevel
        engine.mainMixerNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { buffer, _ in
            guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { reportOutput?(0); return }
            var energy: Float = 0
            for i in 0..<Int(buffer.frameLength) { let value = samples[i * buffer.stride]; energy += value * value }
            reportOutput?(min(1, sqrt(energy / Float(buffer.frameLength)) * 6))
        }
        meterInstalled = true
        engine.prepare()
        try engine.start()
        player.play()
        let queue = PCMInputQueue(emit: emit, meter: onLevel ?? { _ in },
                                  received: onInputBuffer ?? { _ in }, failure: failure)
        capture = queue
        try queue.start()
    }
    func stopCapture() { capture?.stop(); capture = nil }
    func play(_ data: Data) throws {
        pendingPCM.append(data)
        let count = pendingPCM.count / 2
        guard count > 0 else { return }
        guard pendingSamples + count <= 16000 * 20 else { throw AudioError.playbackOverflow }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: AVAudioFrameCount(count)),
              let samples = buffer.floatChannelData?[0] else { throw AudioError.format }
        buffer.frameLength = AVAudioFrameCount(count)
        let bytes = [UInt8](pendingPCM.prefix(count * 2))
        for index in 0..<count {
            let raw = UInt16(bytes[2 * index]) | (UInt16(bytes[2 * index + 1]) << 8)
            samples[index] = Float(Int16(bitPattern: raw)) / 32768
        }
        pendingPCM.removeFirst(count * 2)
        pendingSamples += count
        onPlaybackChanged?(true)
        let generation = playbackGeneration
        player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.playbackGeneration == generation else { return }
                self.pendingSamples = max(0, self.pendingSamples - count)
                self.onPlaybackChanged?(self.pendingSamples > 0)
            }
        }
        if !player.isPlaying { player.play() }
    }
    func clearPlayback() {
        playbackGeneration = UUID()
        player.stop()
        pendingSamples = 0; pendingPCM.removeAll()
        onPlaybackChanged?(false); onOutputLevel?(0)
    }
    func shutdown() {
        stopCapture(); clearPlayback(); engine.stop()
        if meterInstalled { engine.mainMixerNode.removeTap(onBus: 0); meterInstalled = false }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    var isSpeaker: Bool {
        AVAudioSession.sharedInstance().currentRoute.outputs.contains { $0.portType == .builtInSpeaker }
    }
    var inputName: String {
        AVAudioSession.sharedInstance().currentRoute.inputs.map(\.portName).joined(separator: "、")
    }
    var routeName: String {
        AVAudioSession.sharedInstance().currentRoute.outputs.map(\.portName).joined(separator: "、")
    }
}
