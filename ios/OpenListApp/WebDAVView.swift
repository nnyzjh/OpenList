import SwiftUI

// WebDAV 页：服务开关 + 地址 + 账号。
// 服务开关改的是 core 里用户权限的 bit 8（读），默认管理员读是开的；
// 开关状态从 /api/me 读。写权限（上传、改名、删除）不在 App 里显示，
// 要改去网页管理页改；写权限仅限管理员账号（一般给其他账号只读）。
struct WebDAVView: View {
    @EnvironmentObject var appState: AppState
    @State private var copied: String?

    private var webdavBase: String { "http://127.0.0.1:5244/dav" }

    private var readBinding: Binding<Bool> {
        Binding(
            get: { appState.user?.webdavRead ?? false },
            set: { newValue in
                Task {
                    await appState.setWebDAV(
                        read: newValue,
                        write: appState.user?.webdavWrite ?? false
                    )
                }
            }
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section("开关") {
                    Toggle("服务开关", isOn: readBinding)
                    if let error = appState.lastError {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.footnote)
                    }
                }

                Section("地址") {
                    CopyRow(label: "本机", value: webdavBase, copied: $copied)
                    if let lan = lanIPAddress() {
                        CopyRow(label: "同一 Wi-Fi 下的其他设备", value: "http://\(lan):5244/dav", copied: $copied)
                    }
                }

                Section("账号") {
                    CopyRow(label: "用户名", value: appState.adminUsername, copied: $copied)
                    CopyRow(label: "密码", value: appState.adminPassword, copied: $copied)
                }

                Section {
                    Text("在 VidHub / Infuse 里添加 WebDAV 源，填上面的地址和账号就能用。密码明文显示，因为这是你自己的本机服务。注意：切到播放器后本 App 到了后台；开着“后台运行”服务会多活一会儿，自动停止设了时间才会停。停服务也不会丢数据，数据一直在手机上。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("WebDAV")
        }
    }

    /// 本机在 Wi-Fi 下的 IP（en0）。拿不到就只显示 127.0.0.1。
    private func lanIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let current = ptr {
            let ifa = current.pointee
            let name = String(cString: ifa.ifa_name)
            if name == "en0",
               let sa = ifa.ifa_addr,
               sa.pointee.sa_family == UInt8(AF_INET) {
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(sa, socklen_t(sa.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
                address = String(cString: host)
                break
            }
            ptr = ifa.ifa_next
        }
        return address
    }
}

// 一行“值 + 复制按钮”。密码明文显示，因为这是用户自己的本机服务。
struct CopyRow: View {
    let label: String
    let value: String
    @Binding var copied: String?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.footnote)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Button {
                UIPasteboard.general.string = value
                copied = label
            } label: {
                Label(copied == label ? "已复制" : "复制", systemImage: "doc.on.doc")
                    .font(.footnote)
            }
            .buttonStyle(.plain)
        }
    }
}
