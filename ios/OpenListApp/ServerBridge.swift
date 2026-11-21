import Foundation
import OpenListCore

// 壳与 Go 核心之间的桥。
//
// 注意：这里调的 Mobile* 函数是 gomobile bind 从 mobile 包生成的：
//   Go 包名 mobile → Objective-C 前缀 Mobile，
//   框架名 OpenListCore.xcframework → Swift 模块名 OpenListCore。
// 如果将来改了包名或框架名，这里要跟着改名（一处即可）。
enum ServerBridge {

    /// App 的 Documents 目录 —— core 的全部数据都放这里
    ///（config.json、data.db、日志、索引）。
    static func documentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// 用户文件的根目录（Documents/Files），挂成 /local 存储。
    /// 注意：不要直接把 Documents 当存储根目录，那样会把 config.json、
    /// data.db 这些核心文件也暴露在文件列表里，误删就坏了。
    static func filesDirectory() -> URL {
        documentsDirectory().appendingPathComponent("Files", isDirectory: true)
    }

    /// 启动核心：定好数据目录和管理员密码，然后 Init + Start。
    /// 只调一次；重复启动由 AppState 把关。
    static func start(adminPassword: String) {
        let docs = documentsDirectory()
        let files = filesDirectory()
        try? FileManager.default.createDirectory(at: files, withIntermediateDirectories: true)
        MobileSetDataDir(docs.path)
        MobileSetAdminPassword(adminPassword)
        MobileInit()
        MobileStart()
    }

    /// 再启动一次（切回前台时用）。Init 已做过，只需 Start。
    static func restart() {
        MobileStart()
    }

    /// 停掉全部服务并关闭数据库（切后台时调）。
    static func stop() {
        MobileShutdown()
    }

    /// HTTP 服务是否在跑。
    static var isRunning: Bool {
        MobileIsRunning()
    }

    /// 编译进核心的版本号（例如 "v4.2.9"），
    /// 和 /api/public/settings 里 "version" 的主版本号是一致的。
    static var coreVersion: String {
        MobileVersion()
    }

    /// 重置管理员密码（不删任何数据）。用 core 自己的方式把 admin 的密码
    /// 改成新值，不需要旧密码。返回 "" 表示成功，否则是错误信息。
    /// 只在数据库已打开时可用（启动后）。注意：这一步绕过登录接口，
    /// 所以账号被 429 锁定时也能改密码；但改完立刻登录仍可能撞上 429，
    /// 要等锁过期（5 分钟）再登录。
    static func resetAdminPassword(_ newPassword: String) -> String {
        MobileResetAdminPassword(newPassword)
    }
}
