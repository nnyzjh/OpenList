import SwiftUI

// 设置页：通用（后台运行 / 自动停止 / 自动运行）、管理员密码、
// 版本、服务、存储列表、抹掉重来。照着商店版 AList 的设置页排的。
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showResetConfirm = false
    @State private var editUsername = ""
    @State private var editPassword = ""
    @State private var accountMessage: String?

    /// 自动停止的选项（小时）。0 = 不停止。
    private let autoStopOptions = [0, 1, 2, 4, 8, 12, 24]

    var body: some View {
        NavigationStack {
            List {
                Section("通用") {
                    Toggle("后台运行", isOn: $appState.backgroundKeepAlive)
                    Text("开启后服务常驻后台，息屏也可访问服务。切后台时先把数据库落盘（挂载的账号密码/密钥/token/cookie 都写进 data.db），之后就算不小心把 App 从后台划掉，挂载和账号也都在，不会丢。会多耗电，iOS 仍可能挂起 App。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Picker("自动停止", selection: $appState.autoStopHours) {
                        ForEach(autoStopOptions, id: \.self) { hours in
                            Text(hours == 0 ? "不停止" : "\(hours) 小时").tag(hours)
                        }
                    }
                    Text("X 小时未使用时自动停止服务（只停服务，不删数据）。0 代表不自动停止。建议设为 4，因为单集影视通常不超过 4 小时。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Toggle("自动运行", isOn: $appState.autoRun)
                    Text("App 冷启动时自动启动服务。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .onChange(of: appState.backgroundKeepAlive) { newValue in
                    if newValue {
                        appState.requestNotificationPermission()
                    }
                }

                Section("管理员账号") {
                    TextField("用户名", text: $editUsername)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    TextField("密码", text: $editPassword)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    Button("保存账号") {
                        Task {
                            let ok = await appState.setAdminAccount(username: editUsername, password: editPassword)
                            if ok {
                                accountMessage = "账号已保存，App、管理页、WebDAV 用的都是这个账号。"
                            } else {
                                accountMessage = appState.lastError ?? "保存失败。"
                            }
                        }
                    }
                    .disabled(editUsername.isEmpty || editPassword.isEmpty)
                    if let msg = accountMessage {
                        Text(msg)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    Text("一个账号：用户名和密码都能改，不强制是 admin，初始是 admin / admin。改完 App、管理页、WebDAV 用的都是新的，不用旧密码，不删数据。账号明文显示，因为这是你自己的本机服务。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Section("版本") {
                    Text(appState.versionString.isEmpty ? "读取中…" : appState.versionString)
                        .font(.footnote)
                        .textSelection(.enabled)
                    LabeledRow(label: "核心版本", value: ServerBridge.coreVersion)
                    LabeledRow(
                        label: "壳版本",
                        value: (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")
                            + " ("
                            + (Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?")
                            + ")"
                    )
                }

                Section("服务") {
                    LabeledRow(
                        label: "状态",
                        value: ServerBridge.isRunning ? "运行中" : "已停止"
                    )
                    LabeledRow(label: "本机地址", value: "http://127.0.0.1:5244")
                    Button {
                        if let url = URL(string: "http://127.0.0.1:5244") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("在 Safari 里打开管理页", systemImage: "safari")
                    }
                    Text("管理页是 core 自带的网页版，完整的设置（添加别的网盘、用户管理等）都在那里。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Section("存储") {
                    if appState.storages.isEmpty {
                        Text("没有存储")
                            .foregroundColor(.secondary)
                    }
                    ForEach(appState.storages) { storage in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(storage.mount_path)
                            Text("\(storage.driver) · \(storage.status.isEmpty ? "正常" : storage.status)")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section("危险区") {
                    Button(role: .destructive) {
                        showResetConfirm = true
                    } label: {
                        Label("抹掉全部数据并重新开始", systemImage: "trash")
                    }
                    Text("删掉配置、数据库、日志、索引和 Files 文件夹里的全部文件，然后重新走一遍启动流程。钥匙串里的管理员密码不动。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Section {
                    Text("OpenList 核心 v4.2.9（AGPL-3.0），作者 The OpenList Projects Contributors。本 App 是自用编译版，只改了壳，没改核心。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("设置")
            .onAppear {
                // 账号框默认填当前值（只在空着的时候填，不覆盖正在改的内容）。
                if editUsername.isEmpty { editUsername = appState.adminUsername }
                if editPassword.isEmpty { editPassword = appState.adminPassword }
            }
            .confirmationDialog(
                "抹掉全部数据？",
                isPresented: $showResetConfirm,
                titleVisibility: .visible
            ) {
                Button("抹掉并重新开始", role: .destructive) {
                    Task { await appState.resetAllData() }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("配置、数据库和 Files 文件夹里的文件都会删掉，这个操作不能撤销。")
            }
        }
    }
}
