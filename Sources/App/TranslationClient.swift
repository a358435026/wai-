import Foundation

@MainActor
protocol TranslationClient: AnyObject {
    func connect(key: String, configuration: ASTConfiguration) async throws
    func sendAudio(_ pcm: Data) async throws
    func finish() async throws
    func disconnect()
}

@MainActor
final class BailianClient: TranslationClient {
    private let endpoint: URL
    private let session = URLSession(configuration: .ephemeral)
    private var socket: URLSessionWebSocketTask?
    private var receiver: Task<Void, Never>?
    private var ping: Task<Void, Never>?
    private var closed = false
    private var ready = false
    private var decoder = BailianDecoder()
    private let onResponse: (ASTResponse) -> Void
    private let onError: (Error) -> Void
    init(host: String, onResponse: @escaping (ASTResponse) -> Void, onError: @escaping (Error) -> Void) throws {
        endpoint = try BailianWire.endpoint(host: host)
        self.onResponse = onResponse; self.onError = onError
    }
    func connect(key: String, configuration: ASTConfiguration) async throws {
        let start = try BailianWire.start(configuration)
        var request = URLRequest(url:endpoint)
        request.setValue("Bearer " + key, forHTTPHeaderField:"Authorization")
        let task = session.webSocketTask(with:request)
        task.maximumMessageSize = 4 * 1024 * 1024; socket = task; task.resume()
        receiver = Task { [weak self] in
            guard let self else { return }
            do {
                var configured = false
                while !Task.isCancelled && !self.closed {
                    let message = try await task.receive()
                    guard !self.closed else { break }
                    let bytes: Data
                    switch message {
                    case .string(let value): bytes = Data(value.utf8)
                    case .data(let value): bytes = value
                    @unknown default: throw BailianError("百炼响应格式不可识别。")
                    }
                    let object = try JSONSerialization.jsonObject(with:bytes) as? [String:Any]
                    if object?["type"] as? String == "session.created" {
                        guard !configured else { continue }
                        configured = true
                        try await self.send(start)
                        continue
                    }
                    for response in try self.decoder.decode(bytes) {
                        if response.event == 150 {
                            guard configured, !self.ready else { continue }
                            self.ready = true
                        }
                        self.onResponse(response)
                    }
                }
            } catch {
                if !self.closed && !Task.isCancelled {
                    self.onError(BailianError(error.localizedDescription.replacingOccurrences(of:key, with:"[Key已隐藏]")))
                }
            }
        }
        ping = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds:15_000_000_000) } catch { break }
                guard let self, !self.closed else { break }
                do {
                    try await withCheckedThrowingContinuation { (continuation:CheckedContinuation<Void,Error>) in
                        task.sendPing { error in
                            if let error { continuation.resume(throwing:error) } else { continuation.resume() }
                        }
                    }
                } catch { if !self.closed { self.onError(error) }; break }
            }
        }
    }
    func sendAudio(_ pcm: Data) async throws {
        guard ready else { throw BailianError("百炼尚未确认会话配置。") }
        try await send(BailianWire.audio(pcm))
    }
    func finish() async throws { try await send(BailianWire.finish) }
    private func send(_ data: Data) async throws {
        guard !closed, let socket, let value = String(data:data, encoding:.utf8) else { throw BailianError("百炼连接已结束。") }
        try await socket.send(.string(value))
    }
    func disconnect() {
        guard !closed else { return }
        closed = true; receiver?.cancel(); ping?.cancel()
        socket?.cancel(with:.normalClosure, reason:nil); socket = nil
        session.invalidateAndCancel()
    }
}
