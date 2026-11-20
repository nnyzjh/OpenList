import Foundation

// 与 core 的 HTTP API（127.0.0.1:5244）打交道。
// 壳永远通过这些接口读写，不直接读磁盘上的文件 ——
// 这样出错时拿到的是 core 返回的明确错误，而不是壳自己猜。
enum APIError: LocalizedError {
    case httpStatus(Int, String)
    case apiError(Int, String)
    case transport(Error)
    case decoding(Error)
    case noData

    var errorDescription: String? {
        switch self {
        case .httpStatus(let code, let msg): return "HTTP \(code)：\(msg)"
        case .apiError(let code, let msg): return "接口错误 \(code)：\(msg)"
        case .transport(let e): return "连不上本机服务：\(e.localizedDescription)"
        case .decoding(let e): return "接口返回解析失败：\(e.localizedDescription)"
        case .noData: return "接口没有返回数据"
        }
    }
}

final class APIClient: ObservableObject {
    static let shared = APIClient()

    static let baseURL = URL(string: "http://127.0.0.1:5244")!

    @Published var token: String?

    private let session = URLSession(configuration: .default)
    private let decoder = JSONDecoder()

    // MARK: - 通用请求

    private func makeRequest(path: String, method: String, jsonBody: Data? = nil) -> URLRequest {
        var req = URLRequest(url: Self.baseURL.appendingPathComponent(path))
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token {
            // core 的鉴权就是 Authorization 头里直接放 token（不用 Bearer 前缀）。
            req.setValue(token, forHTTPHeaderField: "Authorization")
        }
        req.httpBody = jsonBody
        return req
    }

    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error)
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.noData }
        // 先按信封解析；信封里 code != 200 就是业务错误。
        do {
            let envelope = try decoder.decode(APIResponse<T>.self, from: data)
            guard envelope.code == 200 else {
                throw APIError.apiError(envelope.code, envelope.message)
            }
            // 有些接口成功时不返回 data（比如改用户、首次安装），
            // 这时只要 code 是 200 就算成功，不用非要 data。
            if T.self == EmptyData.self {
                return EmptyData() as! T
            }
            guard let value = envelope.data else { throw APIError.noData }
            return value
        } catch let e as APIError {
            throw e
        } catch {
            // 信封都解析不了时，把 HTTP 状态和原文一起报出来。
            let body = String(data: data, encoding: .utf8) ?? ""
            if http.statusCode != 200 {
                throw APIError.httpStatus(http.statusCode, body)
            }
            throw APIError.decoding(error)
        }
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        try await send(makeRequest(path: path, method: "GET"))
    }

    private func postJSON<T: Decodable, B: Encodable>(_ path: String, _ body: B) async throws -> T {
        let data = try JSONEncoder().encode(body)
        return try await send(makeRequest(path: path, method: "POST", jsonBody: data))
    }

    // MARK: - 存活与初始化

    /// GET /ping，200 且正文是 "pong" 表示服务已起来。
    func ping() async -> Bool {
        var req = URLRequest(url: Self.baseURL.appendingPathComponent("ping"))
        req.httpMethod = "GET"
        req.timeoutInterval = 2
        do {
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return false }
            return String(data: data, encoding: .utf8) == "pong"
        } catch {
            return false
        }
    }

    /// GET /api/public/init_status → {"initialized": true/false}
    func initStatus() async throws -> Bool {
        let data: InitStatusData = try await get("/api/public/init_status")
        return data.initialized
    }

    /// POST /api/public/init/setup —— 官方的首次安装接口。
    /// 正常情况下 core 在启动时已经用环境变量里的密码建好了 admin，
    /// 这个只是兜底：万一 admin 还没建好，就用它补建一次。
    /// 已初始化时 core 会报 "system has already been initialized"，调用方忽略即可。
    func initSetup(username: String, password: String) async throws {
        struct SetupReq: Encodable {
            let username: String
            let password: String
            let site_title: String = "OpenList"
        }
        let _: EmptyData = try await postJSON("/api/public/init/setup", SetupReq(username: username, password: password))
    }

    // MARK: - 登录与用户

    /// POST /api/auth/login → {"token": "..."}
    func login(username: String, password: String) async throws -> String {
        let body = ["username": username, "password": password]
        let data: TokenData = try await postJSON("/api/auth/login", body)
        token = data.token
        return data.token
    }

    /// GET /api/me → 当前用户（含 permission 权限位）。
    func me() async throws -> UserData {
        try await get("/api/me")
    }

    /// POST /api/admin/user/update —— 必须把整个用户对象发回去，
    /// password 留空表示不改密码（core 会保留原来的密码哈希）。
    func updateUser(_ user: UserData) async throws {
        var copy = user
        copy.password = ""
        let _: EmptyData = try await postJSON("/api/admin/user/update", copy)
    }

    // MARK: - 设置与版本

    /// GET /api/public/settings → {"version": "v4.2.9 (Commit: ...) - Frontend: ... - Build at: ...", ...}
    /// 不用登录就能调。
    func publicSettings() async throws -> [String: String] {
        try await get("/api/public/settings")
    }

    // MARK: - 存储

    /// GET /api/admin/storage/list → {"content": [...], "total": n}
    func listStorages() async throws -> [StorageData] {
        let data: StorageListData = try await get("/api/admin/storage/list")
        return data.content
    }

    /// POST /api/admin/storage/create —— 建一个 Local 驱动的存储，
    /// 根目录就是壳传进来的绝对路径。addition 是 JSON 字符串。
    func createLocalStorage(mountPath: String, rootFolderPath: String, remark: String) async throws -> Int {
        struct CreateReq: Encodable {
            let mount_path: String
            let driver: String
            let addition: String
            let remark: String
            let order: Int = 0
            let cache_expiration: Int = 0
        }
        struct CreateResp: Decodable { let id: Int }
        let additionDict: [String: Any] = [
            "root_folder_path": rootFolderPath,
            "thumbnail": true,
            "show_hidden": true,
        ]
        let additionData = try JSONSerialization.data(withJSONObject: additionDict)
        let addition = String(data: additionData, encoding: .utf8) ?? "{}"
        let req = CreateReq(mount_path: mountPath, driver: "Local", addition: addition, remark: remark)
        let resp: CreateResp = try await postJSON("/api/admin/storage/create", req)
        return resp.id
    }

    // MARK: - 文件

    /// POST /api/fs/list {"path", "page", "per_page", "refresh"} → {content, total, ...}
    /// per_page 传 0 时 core 默认给全部（PageReq.Validate 会把 <1 的值改成最大值）。
    func listFiles(path: String, refresh: Bool = false) async throws -> FsListData {
        struct ListReq: Encodable {
            let path: String
            let password: String = ""
            let page: Int = 1
            let per_page: Int = 0
            let refresh: Bool
        }
        return try await postJSON("/api/fs/list", ListReq(path: path, refresh: refresh))
    }

    /// POST /api/fs/get {"path"} → {raw_url, ...}，raw_url 就是可直接播/打开的地址。
    func getFile(path: String) async throws -> FileDetail {
        struct GetReq: Encodable {
            let path: String
            let password: String = ""
        }
        return try await postJSON("/api/fs/get", GetReq(path: path))
    }

    // MARK: - 地址拼接

    /// thumb 字段是相对路径（/d/...），拼上本机地址才是完整 URL。
    /// raw_url 一般已经是完整地址，以防万一也做同样处理。
    static func absoluteURL(_ raw: String) -> URL? {
        if raw.hasPrefix("http://") || raw.hasPrefix("https://") {
            return URL(string: raw)
        }
        return URL(string: raw, relativeTo: baseURL)?.absoluteURL
    }
}
