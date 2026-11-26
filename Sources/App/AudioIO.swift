import AVFoundation
import Foundation

// Only the audio tap calls this object. All state is kept on that callback thread.
private final class CaptureConverter: @unchecked Sendable {
    private let converter: AVAudioConverter
    private let outputFormat: AVAudioFormat
    private var framer = PCMFramer()
    private let emit: @Sendable (Data) -> Void
    private let failure: @Sendable (String) -> Void
    private var failed = false
    private let lock = NSLock()

    init(input: AVAudioFormat, emit: @escaping @Sendable (Data) -> Void,
         failure: @escaping @Sendable (String) -> Void) throws {
        guard input.sampleRate > 0, input.channelCount > 0,
              let output = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000,
                                         channels: 1, interleaved: true),
              let converter = AVAudioConverter(from: input, to: output) else { throw AudioError.format }
        self.converter = converter; outputFormat = output
        self.emit = emit; self.failure = failure
    }
    func consume(_ input: AVAudioPCMBuffer) {
        lock.lock(); defer { lock.unlock() }
        guard !failed else { return }
        let capacity = AVAudioFrameCount(ceil(Double(input.frameLength) * 16000 / input.format.sampleRate) + 32)
        guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else { return }
        var used = false
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, inputStatus in
            if used { inputStatus.pointee = .noDataNow; return nil }
            used = true; inputStatus.pointee = .haveData; return input
        }
        if error != nil || status == .error {
            failed = true; failure("麦克风音频转换失败，请重新开始。"); return
        }
        guard output.frameLength > 0, let pointer = output.int16ChannelData?[0] else { return }
        let data = Data(bytes: pointer, count: Int(output.frameLength) * 2)
        framer.append(data).forEach(emit)
    }
    func finish() {
        lock.lock(); defer { lock.unlock() }
        if let remainder = framer.finish() { emit(remainder) }
    }
}

enum AudioError: LocalizedError {
    case format, playbackOverflow
    var errorDescription: String? {
        switch self {
        case .format: return "当前音频设备无法使用，请断开异常音频设备后重试。"
        case .playbackOverflow: return "译音积压超过 20 秒，已停止同传。请检查网络后重新开始。"
        }
    }
}

@MainActor
final class AudioIO {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var capture: CaptureConverter?
    private var tapInstalled = false
    var onLevel: (@Sendable (Float) -> Void)?
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
        try session.setCategory(.playAndRecord, mode: .voiceChat,
                                options: [.defaultToSpeaker, .allowBluetooth])
        try session.setPreferredIOBufferDuration(0.02)
        try session.setActive(true)
        engine.attach(player)
        try engine.inputNode.setVoiceProcessingEnabled(true)
        engine.connect(player, to: engine.mainMixerNode, format: outputFormat)
        let input = engine.inputNode.outputFormat(forBus: 0)
        let converter = try CaptureConverter(input: input, emit: emit, failure: failure)
        capture = converter
        let reportLevel = onLevel
        engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: input) { buffer, _ in
            if let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 {
                var energy: Float = 0
                for i in 0..<Int(buffer.frameLength) { energy += samples[i] * samples[i] }
                reportLevel?(min(1, sqrt(energy / Float(buffer.frameLength)) * 8))
            }
            converter.consume(buffer)
        }
        tapInstalled = true
        engine.prepare()
        try engine.start()
        player.play()
    }
    func stopCapture() {
        if tapInstalled { engine.inputNode.removeTap(onBus: 0); tapInstalled = false }
        capture?.finish(); capture = nil
    }
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
        onPlaybackChanged?(false)
    }
    func shutdown() {
        stopCapture(); clearPlayback(); engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    var routeName: String {
        AVAudioSession.sharedInstance().currentRoute.outputs.map(\.portName).joined(separator: "、")
    }
}
