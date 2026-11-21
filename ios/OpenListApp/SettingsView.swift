import SwiftUI

// 设置页：版本号、服务状态、存储列表、抹掉重来。
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showResetConfirm = false

    var body: some View {
        NavigationStack {
            List {
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

                Section("后台运行") {
                    Toggle("后台运行", isOn: $appState.backgroundKeepAlive)
                    Text("开启后切到后台不立即停服，服务多活一会儿；息屏也可访问服务。会多耗电，iOS 仍可能挂起 App。默认关闭。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .onChange(of: appState.backgroundKeepAlive) { newValue in
                    if newValue {
                        appState.requestNotificationPermission()
                    }
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
