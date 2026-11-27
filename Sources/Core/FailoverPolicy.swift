import Foundation

public enum FailoverPolicy {
    public static func configuration(for destination: TranslationProvider, current: ASTConfiguration,
                                     automaticSource: String) -> ASTConfiguration? {
        var result = current
        if destination == .bailian {
            guard current.source != "zhen", current.target != "zhen",
                  let language = BailianLanguages.target(current.target),
                  current.mode != .speechToSpeech || language.defaultSpeech else { return nil }
        } else {
            let source = current.source == "bailian-auto" ? automaticSource : current.source
            guard ASTLanguages.validationError(source: source, target: current.target) == nil,
                  current.mode != .speechToSpeech || ASTLanguages.target(current.target)?.defaultSpeech == true else { return nil }
            result.source = source
        }
        return result
    }
    public static func destination(current: TranslationProvider, tried: Set<TranslationProvider>,
                                   configured: Set<TranslationProvider>) -> TranslationProvider? {
        let other: TranslationProvider = current == .bailian ? .volcengine : .bailian
        return configured.contains(other) && !tried.contains(other) ? other : nil
    }
}

// Only completed source sentences awaiting translation start a latency deadline.
// Silence, partial ASR, muted input and local speaker suppression never start it.
public struct TranslationHealth: Sendable {
    public private(set) var pendingSince: Date?
    public private(set) var lastLatency: TimeInterval?
    private var sourceOpen = false
    private var translatedDuringSource = false
    public init() {}
    public mutating func sourceBegan() {
        if !sourceOpen { sourceOpen = true; translatedDuringSource = false }
    }
    public mutating func sourceCompleted(at time: Date) {
        if !translatedDuringSource && pendingSince == nil { pendingSince = time }
        sourceOpen = false
    }
    public mutating func translated(at time: Date) {
        translatedDuringSource = true
        if let start = pendingSince { lastLatency = max(0, time.timeIntervalSince(start)) }
        pendingSince = nil
    }
    public func stalled(at time: Date, suspended: Bool, threshold: TimeInterval = 10) -> Bool {
        guard !suspended, let start = pendingSince else { return false }
        return time.timeIntervalSince(start) >= threshold
    }
}
