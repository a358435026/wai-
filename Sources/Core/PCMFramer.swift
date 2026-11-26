import Foundation

public struct PCMFramer {
    public static let frameBytes = 2560 // 80 ms, 16 kHz, mono, signed 16-bit LE.
    private var pending = Data()
    public init() {}
    public mutating func append(_ data: Data) -> [Data] {
        pending.append(data)
        var frames: [Data] = []
        while pending.count >= Self.frameBytes {
            frames.append(Data(pending.prefix(Self.frameBytes)))
            pending.removeFirst(Self.frameBytes)
        }
        return frames
    }
    public mutating func finish() -> Data? {
        defer { pending.removeAll() }
        guard !pending.isEmpty else { return nil }
        return pending
    }
}

public struct Caption: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var text: String
    public var final: Bool
    public init(id: UUID = UUID(), text: String = "", final: Bool = false) {
        self.id = id; self.text = text; self.final = final
    }
}

public struct CaptionLane: Sendable {
    public private(set) var captions: [Caption] = []
    public init() {}
    public mutating func begin() {
        if let last = captions.last, !last.final, last.text.isEmpty { return }
        if !captions.isEmpty { captions[captions.count - 1].final = true }
        captions.append(Caption())
        if captions.count > 100 { captions.removeFirst(captions.count - 100) }
    }
    // AST subtitle response events carry successive text fragments.
    public mutating func append(_ text: String) {
        if captions.last == nil || captions.last!.final { begin() }
        captions[captions.count - 1].text += text
    }
    public mutating func end() {
        if !captions.isEmpty { captions[captions.count - 1].final = true }
    }
}
