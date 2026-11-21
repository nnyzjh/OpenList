import AVFoundation
import Foundation
import SwiftUI
import UserNotifications

// App 的总状态机：启动核心 → 登录 → 建好本地存储 → 就绪。
// 全部网络操作都走 APIClient（即 core 的 HTTP API），
// 壳自己不读磁盘文件，错了就显示 core 报的原话。
// 例外：日志页直接读 Documents/log/log.log（core 没有现成的日志接口）。
@MainActor
final class AppState: ObservableObject {

    enum Phase {
        case starting(String)   // 正在启动，带一句进度
        case ready
        case failed(String)     // 启动失败，带原因
    }

    @Published var phase: Phase = .starting("正在启动服务…")
    @Published var user: UserData?
    @Published var versionString: String = ""
    @Published var storages: [StorageData] = []
    @Published var adminPassword: String = ""
    @Published var lastError: String?

    /// 后台运行（保活）开关，默认关。开着时切后台不立即停服，
    /// 改放无声音频 + 发一条通知；关着就按老样子切后台停服务。
    /// 存在 UserDefaults 里。注意：不要用 @AppStorage —— 它是 SwiftUI 的
    /// 属性包装器，放在 ObservableObject 里冷启动会闪退；这里用
    /// @Published + UserDefaults 手动同步（启动时读一次、改了就存）。
    @Published var backgroundKeepAlive: Bool = UserDefaults.standard.bool(forKey: "backgroundKeepAlive") {
        didSet {
            UserDefaults.standard.set(backgroundKeepAlive, forKey: "backgroundKeepAlive")
        }
    }

    private let api = APIClient.shared
    private var started = false
    private let audioKeeper = SilentAudioKeeper()

    static let localMountPath = "/local"
    static let localRemark = "本地文件"

    // MARK: - 启动

    func startup() async {
        guard !started else { return }
        started = true
        phase = .starting("正在启动服务…")
        do {
            // 1. 管理员密码：钥匙串里取，没有就随机生成一个存起来。
            let password = KeychainHelper.getOrCreateAdminPassword()
            adminPassword = password

            // 2. 启动 Go 核心（数据目录 = Documents，密码先传进去，
            //    首次启动 core 会用这个密码自动建好 admin 账号）。
            ServerBridge.start(adminPassword: password)

            // 3. 等 HTTP 服务起来（最多 15 秒）。
            phase = .starting("正在等服务起来…")
            var up = false
            for _ in 0..<30 {
                if await api.ping() { up = true; break }
                try await Task.sleep(nanoseconds: 500_000_000)
            }
            guard up else { throw AppError("本机服务 15 秒都没起来，请重试。") }

            // 4. 万一 admin 还没建好（比如 core 升级改了逻辑），
            //    走官方的安装接口补建一次；已建好时会直接报“已初始化”，忽略即可。
            phase = .starting("正在检查管理员账号…")
            let initialized = try await api.initStatus()
            if !initialized {
                try? await api.initSetup(username: "admin", password: password)
            }

            // 5. 登录，拿到 token。
            phase = .starting("正在登录…")
            _ = try await api.login(username: "admin", password: password)

            // 6. 读当前用户（权限位）和版本号。
            user = try await api.me()
            await refreshVersion()

            // 7. 没有本地存储就建一个（根目录 = Documents/Files）。
            phase = .starting("正在准备本地存储…")
            try await ensureLocalStorage()

            phase = .ready
        } catch {
            started = false
            phase = .failed(error.localizedDescription)
        }
    }

    /// 切到后台：保活开着且服务在跑，就不立即停服 ——
    /// 放无声音频让 App 多活一会儿，并发一条“服务正在运行中”通知；
    /// 保活关着（默认）就按老样子停服务。注意：即便保活开着，
    /// iOS 仍可能因内存压力或音频中断把 App 挂起，保活不是 100% 可靠。
    func onEnterBackground() {
        guard started else { return }
        if backgroundKeepAlive && ServerBridge.isRunning {
            audioKeeper.start()
            postRunningNotification()
        } else {
            audioKeeper.stop()
            clearRunningNotification()
            shutdown()
        }
    }

    /// 回到前台：先停无声音频、清掉那条通知，再走原来的恢复流程。
    func onEnterForeground() async {
        audioKeeper.stop()
        clearRunningNotification()
        await resume()
    }

    /// 切回前台：服务停了就再启动，token 过期就重新登录。
    func resume() async {
        guard started else { return }
        if !ServerBridge.isRunning {
            ServerBridge.restart()
            var up = false
            for _ in 0..<20 {
                if await api.ping() { up = true; break }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
            guard up else {
                phase = .failed("回前台后服务没起来，请点重试。")
                return
            }
        }
        // token 可能过期了，重新登录一次最稳；失败了就留在原状态。
        if let password = KeychainHelper.loadAdminPassword() {
            if (try? await api.login(username: "admin", password: password)) != nil {
                user = try? await api.me()
            }
        }
        if case .failed = phase {
            phase = .ready
        }
    }

    func shutdown() {
        audioKeeper.stop()
        clearRunningNotification()
        ServerBridge.stop()
    }

    // MARK: - 通知（保活提示）

    /// 保活开关打开时顺手要通知权限（只在开的时候问，不打扰）。
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// 切后台保活时发一条“服务正在运行中”通知（固定 id，重复发会覆盖上一条）。
    private func postRunningNotification() {
        let content = UNMutableNotificationContent()
        content.title = "OpenList"
        content.body = "服务正在运行中"
        let request = UNNotificationRequest(identifier: "openlist-service-running", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private func clearRunningNotification() {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["openlist-service-running"])
    }

    func retryStartup() async {
        started = false
        api.token = nil
        await startup()
    }

    // MARK: - 本地存储

    /// 确保有一个 Local 驱动的 /local 存储。
    /// 有就不动；没有就新建；如果已有的 /local 根目录不是当前 Files 目录
    /// （换过容器，旧路径失效了），删掉旧的再重建，避免读到不存在的目录。
    func ensureLocalStorage() async throws {
        storages = try await api.listStorages()
        let currentRoot = ServerBridge.filesDirectory().path
        if let existing = storages.first(where: { $0.driver == "Local" && $0.mount_path == Self.localMountPath }) {
            if localRoot(of: existing) != currentRoot {
                try? await api.deleteStorage(id: existing.id)
                _ = try await api.createLocalStorage(
                    mountPath: Self.localMountPath,
                    rootFolderPath: currentRoot,
                    remark: Self.localRemark
                )
                storages = try await api.listStorages()
            }
            return
        }
        _ = try await api.createLocalStorage(
            mountPath: Self.localMountPath,
            rootFolderPath: currentRoot,
            remark: Self.localRemark
        )
        storages = try await api.listStorages()
    }

    /// 从一个存储的 addition（JSON 字符串）里读 root_folder_path。
    private func localRoot(of storage: StorageData) -> String? {
        guard let data = storage.addition.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json["root_folder_path"] as? String
    }

    // MARK: - WebDAV 开关

    /// 改 WebDAV 读/写权限位（bit 8 读，bit 9 写），通过 /api/admin/user/update
    /// 把整个用户对象发回去。改完重新读一次 /api/me 确认。
    func setWebDAV(read: Bool, write: Bool) async {
        guard var current = user else { return }
        current.webdavRead = read
        current.webdavWrite = write
        do {
            try await api.updateUser(current)
            user = try await api.me()
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - 版本

    func refreshVersion() async {
        if let settings = try? await api.publicSettings(),
           let v = settings["version"], !v.isEmpty {
            versionString = v
        } else {
            versionString = "OpenList \(ServerBridge.coreVersion)"
        }
    }

    // MARK: - 抹掉重来

    /// 停服务，删掉 Documents 下的全部核心数据（配置、数据库、日志、索引、
    /// 临时文件和 Files 文件夹），再走一遍启动流程。
    /// 注意：钥匙串里的管理员密码不动，重建的 admin 还是同一个密码。
    func resetAllData() async {
        shutdown()
        let docs = ServerBridge.documentsDirectory()
        let fm = FileManager.default
        for name in ["config.json", "data.db", "data.db-shm", "data.db-wal", "log", "temp", "bleve", "Files"] {
            try? fm.removeItem(at: docs.appendingPathComponent(name))
        }
        started = false
        api.token = nil
        user = nil
        storages = []
        await startup()
    }
}

struct AppError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

// MARK: - 无声音频保活
// 保活的机制：切后台后循环放一段无声的音频，iOS 把“正在放音频”的 App
// 挂起得晚一些，服务就能多活一会儿。音量是 0，不出声；
// 和别的音频混音（.mixWithOthers），不打断正在放的音乐。
// 注意：这只是“多活一会儿”，iOS 仍可能因内存压力或音频中断挂起 App。
final class SilentAudioKeeper {
    private var player: AVAudioPlayer?
    private var sessionConfigured = false

    /// 开始放无声音频（已在放就什么都不做）。
    func start() {
        guard player == nil else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            if !sessionConfigured {
                try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
                sessionConfigured = true
            }
            try session.setActive(true)
            let data = Self.silentWAV()
            let p = try AVAudioPlayer(data: data)
            p.numberOfLoops = -1  // 无限循环
            p.volume = 0
            p.prepareToPlay()
            p.play()
            player = p
        } catch {
            // 音频起不来就不保活，不报错、不打断正常流程。
            player = nil
        }
    }

    /// 停掉无声音频。
    func stop() {
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    /// 生成 1 秒无声的 WAV（8kHz、单声道、16 位），全是 0 采样。
    private static func silentWAV() -> Data {
        let sampleRate: UInt32 = 8000
        let samples = 8000  // 1 秒
        var data = Data()
        func u32(_ v: UInt32) {
            var x = v.littleEndian
            data.append(Data(bytes: &x, count: 4))
        }
        func u16(_ v: UInt16) {
            var x = v.littleEndian
            data.append(Data(bytes: &x, count: 2))
        }
        func str(_ s: String) { data.append(Data(s.utf8)) }
        let byteRate = sampleRate * 2
        let blockAlign: UInt16 = 2
        let dataSize = samples * 2
        str("RIFF"); u32(36 + UInt32(dataSize)); str("WAVE")
        str("fmt "); u32(16); u16(1); u16(1); u32(sampleRate); u32(byteRate); u16(blockAlign); u16(16)
        str("data"); u32(UInt32(dataSize))
        data.append(Data(count: dataSize))  // 全 0 = 无声
        return data
    }
}
