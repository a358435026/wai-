import AudioToolbox
import Foundation

// Input is independent of the playback graph. Audio Queue converts the hardware
// rate to interleaved mono PCM16, with three reusable 80ms recording buffers.
final class PCMInputQueue: @unchecked Sendable {
    private var queue: AudioQueueRef?
    private let lock = NSLock()
    private var running = false
    private var framer = PCMFramer()
    private let emit: @Sendable (Data) -> Void
    private let meter: @Sendable (Float) -> Void
    private let received: @Sendable (Int) -> Void
    private let failure: @Sendable (String) -> Void
    init(emit: @escaping @Sendable (Data) -> Void, meter: @escaping @Sendable (Float) -> Void,
         received: @escaping @Sendable (Int) -> Void, failure: @escaping @Sendable (String) -> Void) {
        self.emit = emit; self.meter = meter; self.received = received; self.failure = failure
    }
    func start() throws {
        var format = AudioStreamBasicDescription(mSampleRate: 16000, mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 2, mFramesPerPacket: 1, mBytesPerFrame: 2, mChannelsPerFrame: 1,
            mBitsPerChannel: 16, mReserved: 0)
        var created: AudioQueueRef?
        try check(AudioQueueNewInput(&format, { context, queue, buffer, _, _, _ in
            guard let context else { return }
            Unmanaged<PCMInputQueue>.fromOpaque(context).takeUnretainedValue().consume(queue, buffer)
        }, Unmanaged.passUnretained(self).toOpaque(), nil, nil, 0, &created), "创建录音队列")
        guard let created else { throw AudioError.format }
        queue = created
        do {
            for _ in 0..<3 {
                var buffer: AudioQueueBufferRef?
                try check(AudioQueueAllocateBuffer(created, UInt32(PCMFramer.frameBytes), &buffer), "分配收音缓冲")
                guard let buffer else { throw AudioError.format }
                try check(AudioQueueEnqueueBuffer(created, buffer, 0, nil), "排入收音缓冲")
            }
            lock.lock(); running = true; lock.unlock()
            try check(AudioQueueStart(created, nil), "启动录音队列")
        } catch { stop(); throw error }
    }
    private func consume(_ queue: AudioQueueRef, _ buffer: AudioQueueBufferRef) {
        lock.lock()
        guard running else { lock.unlock(); return }
        let data = Data(bytes: buffer.pointee.mAudioData, count: Int(buffer.pointee.mAudioDataByteSize))
        let frames = framer.append(data)
        let status = AudioQueueEnqueueBuffer(queue, buffer, 0, nil)
        if status != noErr { running = false }
        lock.unlock()
        received(data.count); meter(PCMLevel.normalized(data)); frames.forEach(emit)
        if status != noErr { failure("录音缓冲回收失败（\(status)）。请重新开始。") }
    }
    func stop() {
        lock.lock(); running = false; lock.unlock()
        if let queue {
            AudioQueueStop(queue, true); AudioQueueDispose(queue, true)
            self.queue = nil
        }
        lock.lock(); let tail = framer.finish(); lock.unlock()
        if let tail { emit(tail) }
    }
    private func check(_ status: OSStatus, _ operation: String) throws {
        if status != noErr { throw AudioError.queue(operation, status) }
    }
    deinit { if queue != nil { stop() } }
}
