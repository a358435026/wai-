import Foundation

public struct ConnectionFailure: LocalizedError, Equatable, Sendable {
    public let provider: TranslationProvider
    public let status: Int?
    public let code: Int
    public let logID: String
    public init(provider: TranslationProvider, status: Int? = nil, code: Int = 0, logID: String = "") {
        self.provider = provider; self.status = status; self.code = code; self.logID = logID
    }
    public var errorDescription: String? {
        let title = provider.title
        switch status {
        case 401: return "\(title)鉴权失败（HTTP 401）：当前 Key 无效或不属于此语音服务。保存成功不代表接口可用，请重新复制该服务的 Key，并点“测试当前服务连接”。"
        case 403: return "\(title)拒绝访问（HTTP 403）：请检查同传服务权限、业务空间及地域。这不能直接判定为余额不足。"
        case 402: return "\(title)返回支付或额度限制（HTTP 402），请在对应平台检查账单与额度。"
        case 429: return "\(title)请求受限（HTTP 429），请稍后重试或使用备用服务。"
        case .some(let value): return "\(title)握手失败（HTTP \(value)）。请测试连接并检查服务状态。"
        case nil:
            if code == -1011 { return "\(title)握手被拒绝（-1011）。暂未取得HTTP状态，不能判定欠费。请测试连接，核对该平台的语音服务Key与权限。" }
            return "\(title)网络连接失败（\(code)）。请检查网络或使用备用服务；尚不能判定为余额不足。"
        }
    }
}
