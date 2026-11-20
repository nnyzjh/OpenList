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
}
