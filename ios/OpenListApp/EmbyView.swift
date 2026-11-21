import SwiftUI

// Emby 页：伪 Emby 开关 + 链接 + 应用密钥管理。
// core 的伪 Emby 是完整实现（浏览/播放/进度/收藏），
// 只是默认关着（media_emby_enabled=false），在这里打开。
// 密钥是给 Emby 客户端用的：客户端填用户名（admin）+ 密钥当密码，
// 或在请求里带 api_key。密钥明文只在新建时返回一次，
// 之后要看走 Go 的解密（密钥稳定，能再解密出来）。
// 删除是开发者权限：长按底部“设置”图标打开开发者模式才显示删除按钮。
struct EmbyView: View {
    @EnvironmentObject var appState: AppState
    @State private var keys: [AppKeyData] = []
    @State private var embyEnabled = false
    @State private var newKeyName = ""
    @State private var createdKey: CreatedAppKeyData?
    @State private var copied: String?
    @State private var renamingKey: AppKeyData?
    @State private var renameName = ""
    @State private var deletingKey: AppKeyData?
    @State private var error: String?
    @State private var loading = false

    private var embyBase: String { "http://127.0.0.1:5244/@emby" }

    var body: some View {
        NavigationStack {
            List {
                Section("开关") {
                    Toggle("启用 Emby", isOn: Binding(
                        get: { embyEnabled },
                        set: { newValue in
                            let err = ServerBridge.setEmbyEnabled(newValue)
                            if err.isEmpty {
                                embyEnabled = newValue
                            } else {
                                error = err
                            }
                        }
                    ))
                    Text("打开后 Emby 客户端能连 http://127.0.0.1:5244/@emby 浏览和播放。内容来自媒体库，没扫过就是空的，去管理页跑一次媒体扫描。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Section("链接") {
                    CopyRow(label: "Emby 地址", value: embyBase, copied: $copied)
                    Text("Emby 客户端填这个地址，用户名填 \(appState.adminUsername)，密码填下面新建的应用密钥（或者在请求里带 api_key）。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Section("应用密钥") {
                    if keys.isEmpty {
                        Text("还没有密钥，新建一个给 Emby 客户端用。")
                            .foregroundColor(.secondary)
                    }
                    ForEach(keys) { key in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(key.name.isEmpty ? "未命名" : key.name)
                                    Text(key.prefix)
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                    Text("创建于 \(FileTypeHelper.shortDate(key.created_at))")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button {
                                    let plain = ServerBridge.revealAppKey(key.id)
                                    if plain.isEmpty {
                                        error = "取不回密钥明文，请重试。"
                                    } else {
                                        UIPasteboard.general.string = plain
                                        copied = "key-\(key.id)"
                                    }
                                } label: {
                                    Label(copied == "key-\(key.id)" ? "已复制" : "复制密钥", systemImage: "doc.on.doc")
                                        .font(.footnote)
                                }
                                .buttonStyle(.plain)
                            }
                            HStack(spacing: 16) {
                                Button("改名") {
                                    renamingKey = key
                                    renameName = key.name
                                }
                                .font(.footnote)
                                if appState.developerMode {
                                    Button(role: .destructive) {
                                        deletingKey = key
                                    } label: {
                                        Text("删除").font(.footnote)
                                    }
                                }
                            }
                        }
                    }
                    HStack {
                        TextField("新密钥备注名", text: $newKeyName)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        Button("新建") {
                            Task { await createKey() }
                        }
                        .disabled(newKeyName.trimmingCharacters(in: .whitespaces).isEmpty || loading)
                    }
                    if let created = createdKey {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("新建的密钥（只显示一次，复制保存好）：")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            HStack {
                                Text(created.key)
                                    .font(.footnote)
                                    .textSelection(.enabled)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Button {
                                    UIPasteboard.general.string = created.key
                                    copied = "created"
                                } label: {
                                    Label(copied == "created" ? "已复制" : "复制", systemImage: "doc.on.doc")
                                        .font(.footnote)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    if let err = error {
                        Text(err)
                            .foregroundColor(.red)
                            .font(.footnote)
                    }
                    if !appState.developerMode {
                        Text("删除是开发者权限：长按底部“设置”图标打开开发者模式才会显示删除按钮。")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Emby")
            .refreshable { await reload() }
            .task { await reload() }
            .alert("改名", isPresented: Binding(
                get: { renamingKey != nil },
                set: { if !$0 { renamingKey = nil } }
            )) {
                TextField("备注名", text: $renameName)
                Button("保存") {
                    Task {
                        guard let key = renamingKey else { return }
                        let err = ServerBridge.renameAppKey(key.id, newName: renameName.trimmingCharacters(in: .whitespaces))
                        if err.isEmpty {
                            renamingKey = nil
                            await reload()
                        } else {
                            error = err
                        }
                    }
                }
                Button("取消", role: .cancel) { renamingKey = nil }
            }
            .alert("删除这个密钥？", isPresented: Binding(
                get: { deletingKey != nil },
                set: { if !$0 { deletingKey = nil } }
            )) {
                Button("删除", role: .destructive) {
                    Task {
                        guard let key = deletingKey else { return }
                        do {
                            try await APIClient.shared.deleteAppKey(id: key.id)
                            deletingKey = nil
                            await reload()
                        } catch {
                            self.error = error.localizedDescription
                        }
                    }
                }
                Button("取消", role: .cancel) { deletingKey = nil }
            } message: {
                Text("用这个密钥的客户端会立刻连不上。")
            }
        }
    }

    private func reload() async {
        embyEnabled = ServerBridge.isEmbyEnabled
        do {
            keys = try await APIClient.shared.listAppKeys()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func createKey() async {
        let name = newKeyName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        loading = true
        defer { loading = false }
        do {
            createdKey = try await APIClient.shared.createAppKey(name: name)
            newKeyName = ""
            await reload()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
