import Foundation

// MARK: - API envelope
// OpenList 的接口统一返回 {"code": 200, "message": "success", "data": ...}。
// code != 200 表示失败，message 里是原因。
struct APIResponse<T: Decodable>: Decodable {
    let code: Int
    let message: String
    let data: T?
}

struct EmptyData: Decodable {}

struct TokenData: Decodable {
    let token: String
}

struct InitStatusData: Decodable {
    let initialized: Bool
}

// MARK: - User
// 对应 core 里的 model.User（只取壳需要的字段）。
// 注意：回传修改用户时必须把整个对象原样发回去，password 留空表示不改密码。
struct UserData: Codable {
    var id: Int = 0
    var username: String = ""
    var password: String = ""
    var base_path: String = "/"
    var role: Int = 0
    var disabled: Bool = false
    var permission: Int32 = 0
    var sso_id: String = ""
    var allow_ldap: Bool = true

    // WebDAV 权限位（core 定义：bit 8 = webdav 读，bit 9 = webdav 写）。
    var webdavRead: Bool {
        get { (permission & (1 << 8)) != 0 }
        set {
            if newValue { permission |= (1 << 8) } else { permission &= ~(1 << 8) }
        }
    }
    var webdavWrite: Bool {
        get { (permission & (1 << 9)) != 0 }
        set {
            if newValue { permission |= (1 << 9) } else { permission &= ~(1 << 9) }
        }
    }
}

// MARK: - Storage
struct StorageData: Codable, Identifiable {
    var id: Int = 0
    var mount_path: String = ""
    var driver: String = ""
    var order: Int = 0
    var cache_expiration: Int = 0
    var addition: String = ""
    var remark: String = ""
    var status: String = ""
    var disabled: Bool = false
}

struct StorageListData: Decodable {
    var content: [StorageData] = []
    var total: Int = 0
}

// MARK: - Files
struct FileItem: Codable, Identifiable, Hashable {
    var name: String = ""
    var size: Int64 = 0
    var is_dir: Bool = false
    var modified: String = ""
    var sign: String = ""
    var thumb: String = ""
    // 文件类型（core 定义）：0 未知，1 文件夹，2 视频，3 音频，4 文本，5 图片。
    var type: Int = 0

    var id: String { name }

    var isImage: Bool { type == 5 }
    var isVideo: Bool { type == 2 }
    var isAudio: Bool { type == 3 }

    var iconName: String {
        if is_dir { return "folder.fill" }
        if isImage { return "photo.fill" }
        if isVideo { return "film.fill" }
        if isAudio { return "music.note" }
        return "doc.fill"
    }
}

struct FsListData: Decodable {
    var content: [FileItem] = []
    var total: Int = 0
    var readme: String = ""
    var header: String = ""
    var write: Bool = false
}

struct FileDetail: Decodable {
    var name: String = ""
    var size: Int64 = 0
    var is_dir: Bool = false
    var modified: String = ""
    var sign: String = ""
    var thumb: String = ""
    var type: Int = 0
    // 可直接播 / 可直接打开的地址（core 给的，本地驱动是 /p/ 代理地址）。
    var raw_url: String = ""
    var readme: String = ""
}

// MARK: - Helpers

enum FileTypeHelper {
    /// 把 core 返回的 modified（RFC3339 字符串）转成短日期显示。
    static func shortDate(_ raw: String) -> String {
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: raw) {
            let f = DateFormatter()
            f.dateStyle = .short
            f.timeStyle = .short
            return f.string(from: date)
        }
        return String(raw.prefix(16)).replacingOccurrences(of: "T", with: " ")
    }

    /// 字节数转成人类可读的大小。
    static func readableSize(_ bytes: Int64) -> String {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useKB, .useMB, .useGB]
        f.countStyle = .file
        return f.string(fromByteCount: bytes)
    }
}
