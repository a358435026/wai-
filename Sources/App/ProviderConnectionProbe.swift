import Foundation

@MainActor
final class ProviderConnectionProbe {
    private var client: (any TranslationClient)?
    private var continuation: CheckedContinuation<String, Error>?
    private var timer: Task<Void, Never>?
    private var finishing = false
    func run(provider: TranslationProvider, key: String, host: String) async throws -> String {
        try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                let receive: (ASTResponse) -> Void = { [weak self] response in self?.receive(response) }
                let failure: (Error) -> Void = { [weak self] error in self?.complete(.failure(error)) }
                do {
                    client = provider == .bailian ? try BailianClient(host: host, onResponse: receive, onError: failure)
                        : ASTClient(onResponse: receive, onError: failure)
                } catch { complete(.failure(error)); return }
                timer = Task { [weak self] in
                    do { try await Task.sleep(nanoseconds: 10_000_000_000) } catch { return }
                    self?.complete(.failure(BailianError("连接测试超时，已关闭测试会话。")))
                }
                Task { [weak self] in
                    guard let self else { return }
                    do { try await self.client?.connect(key: key, configuration: ASTConfiguration(mode: .subtitles)) }
                    catch { self.complete(.failure(error)) }
                }
            }
        }, onCancel: { Task { @MainActor [weak self] in self?.cancel() } })
    }
    private func receive(_ response: ASTResponse) {
        guard [0, 21000, 20000000].contains(response.statusCode), response.event != 153 else {
            complete(.failure(BailianError("服务拒绝测试：\(response.statusCode) \(response.message)"))); return
        }
        if response.event == 150 && !finishing {
            finishing = true
            Task { [weak self] in
                do {
                    try await self?.client?.finish()
                    self?.complete(.success("鉴权和同传配置通过；已发送结束并关闭测试连接。未录音、未上传音频。"))
                }
                catch { self?.complete(.failure(error)) }
            }
        } else if response.event == 152 || response.event == 151 {
            complete(.success("鉴权与同传会话测试通过；测试会话已关闭。未录音，未上传音频。"))
        }
    }
    func cancel() { complete(.failure(CancellationError())) }
    private func complete(_ result: Result<String, Error>) {
        guard let continuation else { return }
        self.continuation = nil; timer?.cancel(); timer = nil
        client?.disconnect(); client = nil; finishing = false
        continuation.resume(with: result)
    }
}
