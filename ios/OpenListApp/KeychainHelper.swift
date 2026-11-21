import Foundation
import Security

// 管理员密码只存在 iOS 钥匙串里，不写进任何文件、不上传。
// 首次启动默认是 "admin"（和用户名 admin 一样），之后每次启动都用同一个；
// 用户在设置里改了就用改后的。丢了钥匙串（比如换手机没迁钥匙串）
// 就等于丢了密码，只能在设置里抹掉全部数据重来。
// 注意：service/account 不能改，否则旧钥匙串里的密码就找不到了。
enum KeychainHelper {
    private static let service = "com.openlist.ios.admin"
    private static let account = "admin"

    static func loadAdminPassword() -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let password = String(data: data, encoding: .utf8) else {
            return nil
        }
        return password
    }

    @discardableResult
    static func saveAdminPassword(_ password: String) -> Bool {
        guard let data = password.data(using: .utf8) else { return false }
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
            ]
            let update: [String: Any] = [kSecValueData as String: data]
            return SecItemUpdate(query as CFDictionary, update as CFDictionary) == errSecSuccess
        }
        return status == errSecSuccess
    }

    /// 取不到就用默认密码 "admin" 并存起来（初始状态就是 admin / admin）。
    static func getOrCreateAdminPassword() -> String {
        if let existing = loadAdminPassword(), !existing.isEmpty {
            return existing
        }
        saveAdminPassword("admin")
        return "admin"
    }
}
