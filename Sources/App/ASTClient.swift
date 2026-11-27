import Foundation

@MainActor
final class ASTClient: TranslationClient {
    static let endpoint = URL(string: "wss://openspeech.bytedance.com/api/v4/ast/v2/translate")!
    let sessionID = UUID().uuidString
    private let session: URLSession
    private var socket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?
    private var closed = false
    private var receivedBytes = 0
    private let onResponse: (ASTResponse) -> Void
    private let onError: (Error) -> Void

    init(onResponse: @escaping (ASTResponse) -> Void, onError: @escaping (Error) -> Void) {
        self.onResponse = onResponse; self.onError = onError
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        session = URLSession(configuration: config)
    }

    func connect(key: String, configuration: ASTConfiguration) async throws {
        var request = URLRequest(url: Self.endpoint)
        request.setValue(key, forHTTPHeaderField: "X-Api-Key")
        request.setValue("volc.service_type.10053", forHTTPHeaderField: "X-Api-Resource-Id")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Api-Connect-Id")
        let task = session.webSocketTask(with: request)
        task.maximumMessageSize = 4 * 1024 * 1024
        socket = task
        task.resume()
        try await send(ASTRequest.start(sessionID: sessionID, configuration: configuration))
        guard !closed else { return }
        receiveTask = Task { [weak self] in
            guard let self else { return }
            do {
                while !Task.isCancelled && !self.closed {
                    let message = try await task.receive()
                    guard !self.closed else { break }
                    let bytes: Data
                    switch message {
                    case .data(let data): bytes = data
                    case .string: throw ClientError.unexpectedText
                    @unknown default: throw ClientError.unexpectedText
                    }
                    self.receivedBytes += bytes.count
                    let response = try ASTResponse(data: bytes)
                    // One session per socket; the AST gateway can omit response SessionID.
                    // The model generation guard owns connection identity. Do not rely on
                    // a response UUID for routing this dedicated socket's events.
                    self.onResponse(response)
                }
            } catch {
                if !self.closed && !Task.isCancelled { self.onError(WebSocketFailure.wrap(error, task: task, provider: .volcengine)) }
            }
        }
        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: 15_000_000_000) } catch { break }
                guard let self, !self.closed else { break }
                do {
                    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                        task.sendPing { error in
                            if let error { continuation.resume(throwing: error) }
                            else { continuation.resume() }
                        }
                    }
                } catch {
                    if !self.closed && !Task.isCancelled { self.onError(WebSocketFailure.wrap(error, task: task, provider: .volcengine)) }
                    break
                }
            }
        }
    }
    func sendAudio(_ pcm: Data) async throws {
        try await send(ASTRequest.audio(sessionID: sessionID, pcm: pcm))
    }
    func finish() async throws { try await send(ASTRequest.finish(sessionID: sessionID)) }
    private func send(_ data: Data) async throws {
        guard !closed, let socket else { throw ClientError.disconnected }
        do { try await socket.send(.data(data)) }
        catch { throw WebSocketFailure.wrap(error, task: socket, provider: .volcengine) }
    }
    func disconnect() {
        guard !closed else { return }
        closed = true
        receiveTask?.cancel(); pingTask?.cancel()
        socket?.cancel(with: .normalClosure, reason: nil)
        socket = nil
        session.invalidateAndCancel()
    }
    enum ClientError: LocalizedError {
        case disconnected, unexpectedText
        var errorDescription: String? {
            switch self {
            case .disconnected: return "连接已结束，请重新开始同传。"
            case .unexpectedText: return "服务返回了非预期格式，请检查同传服务权限。"
            }
        }
    }
}
