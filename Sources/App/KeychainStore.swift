import Foundation
import Security

enum KeychainStore {
    private static func query(_ provider: TranslationProvider) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: provider == .bailian ? "app.tongchuan.bailian" : "app.tongchuan.volcengine",
         kSecAttrAccount as String: "personal-api-key"]
    }
    static func read(provider: TranslationProvider = .volcengine) -> String? {
        var request = query(provider)
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    static func save(_ key: String, provider: TranslationProvider = .volcengine) throws {
        let attributes: [String: Any] = [
            kSecValueData as String: Data(key.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemUpdate(query(provider) as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            let added = SecItemAdd(query(provider).merging(attributes) { _, new in new } as CFDictionary, nil)
            guard added == errSecSuccess else { throw StoreError.status(added) }
        } else if status != errSecSuccess { throw StoreError.status(status) }
    }
    static func delete(provider: TranslationProvider = .volcengine) throws {
        let status = SecItemDelete(query(provider) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw StoreError.status(status) }
    }
    enum StoreError: LocalizedError {
        case status(OSStatus)
        var errorDescription: String? {
            switch self {
            case .status(let code):
                if code == -34018 { return "安装签名缺少钥匙串权限（-34018），请用TrollStore重新安装或修复签名后重试。" }
                return "钥匙串操作失败（\(code)），请解锁手机后重试。"
            }
        }
    }
}
