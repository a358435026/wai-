import Foundation

enum WebSocketFailure {
    static func wrap(_ error: Error, task: URLSessionWebSocketTask?, provider: TranslationProvider) -> Error {
        let response = task?.response as? HTTPURLResponse
        if let status = response?.statusCode, status != 101 {
            return ConnectionFailure(provider: provider, status: status, code: (error as NSError).code,
                                     logID: response?.value(forHTTPHeaderField: "X-Tt-Logid") ?? "")
        }
        let ns = error as NSError
        return ns.domain == NSURLErrorDomain ? ConnectionFailure(provider: provider, code: ns.code) : error
    }
}
