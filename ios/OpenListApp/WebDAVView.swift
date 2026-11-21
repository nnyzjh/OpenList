import SwiftUI

// WebDAV 页：开关 + 地址 + 账号。
// 开关改的是 core 里用户权限的 bit 8（读）/ bit 9（写），
// 默认管理员读是开的、写是关的；开关状态从 /api/me 读。
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

    private var writeBinding: Binding<Bool> {
        Binding(
            get: { appState.user?.webdavWrite ?? false },
            set: { newValue in
                Task {
                    await appState.setWebDAV(
                        read: appState.user?.webdavRead ?? false,
                        write: newValue
                    )
                }
            }
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section("开关") {
                    Toggle("WebDAV 读取", isOn: readBinding)
                    Toggle("WebDAV 写入（上传、改名、删除）", isOn: writeBinding)
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
                    CopyRow(label: "用户名", value: "admin", copied: $copied)
                    CopyRow(label: "密码", value: appState.adminPassword, copied: $copied, secret: true)
                }

                Section {
                    Text("在 VidHub / Infuse 里添加 WebDAV 源，填上面的地址和账号就能用。注意：切到播放器后本 App 到了后台，服务会停，播放器就连不上——去设置里打开“后台运行”，服务会多活一会儿；iOS 仍可能挂起 App，这是系统限制。")
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

// 一行“值 + 复制按钮”。secret 时默认打码显示，点眼睛才看明文。
struct CopyRow: View {
    let label: String
    let value: String
    @Binding var copied: String?
    var secret: Bool = false

    @State private var revealed: Bool = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Text(secret && !revealed ? String(repeating: "•", count: min(value.count, 12)) : value)
                    .font(.footnote)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            if secret {
                Button {
                    revealed.toggle()
                } label: {
                    Image(systemName: revealed ? "eye.slash" : "eye")
                }
                .buttonStyle(.plain)
            }
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
