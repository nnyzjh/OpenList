import Foundation
import Security

// 管理员密码只存在 iOS 钥匙串里，不写进任何文件、不上传。
// 首次启动随机生成一个，之后每次启动都用同一个；
// 丢了钥匙串（比如换手机没迁钥匙串）就等于丢了密码，
// 只能在设置里抹掉全部数据重来。
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

    /// 取不到就随机生成一个并存起来。
    static func getOrCreateAdminPassword() -> String {
        if let existing = loadAdminPassword(), !existing.isEmpty {
            return existing
        }
        let password = randomPassword(length: 16)
        saveAdminPassword(password)
        return password
    }

    private static func randomPassword(length: Int) -> String {
        let chars = Array("abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789")
        return String((0..<length).map { _ in chars[Int.random(in: 0..<chars.count)] })
    }
}
