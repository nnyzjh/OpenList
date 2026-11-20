import Foundation

// App 的总状态机：启动核心 → 登录 → 建好本地存储 → 就绪。
// 全部网络操作都走 APIClient（即 core 的 HTTP API），
// 壳自己不读磁盘文件，错了就显示 core 报的原话。
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

    private let api = APIClient.shared
    private var started = false

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
        ServerBridge.stop()
    }

    func retryStartup() async {
        started = false
        api.token = nil
        await startup()
    }

    // MARK: - 本地存储

    /// 确保有一个 Local 驱动的 /local 存储；有就不动，没有就新建。
    func ensureLocalStorage() async throws {
        storages = try await api.listStorages()
        if storages.contains(where: { $0.driver == "Local" && $0.mount_path == Self.localMountPath }) {
            return
        }
        _ = try await api.createLocalStorage(
            mountPath: Self.localMountPath,
            rootFolderPath: ServerBridge.filesDirectory().path,
            remark: Self.localRemark
        )
        storages = try await api.listStorages()
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
