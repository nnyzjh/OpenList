import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        switch appState.phase {
        case .starting(let message):
            VStack(spacing: 16) {
                ProgressView()
                Text(message)
                    .foregroundColor(.secondary)
            }
        case .failed(let message):
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.orange)
                Text("启动失败")
                    .font(.headline)
                Text(message)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                Button("重试") {
                    Task { await appState.retryStartup() }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        case .ready:
            TabView {
                FilesRootView()
                    .tabItem { Label("文件", systemImage: "folder.fill") }
                WebDAVView()
                    .tabItem { Label("WebDAV", systemImage: "network") }
                LogsView()
                    .tabItem { Label("日志", systemImage: "doc.text.fill") }
                SettingsView()
                    .tabItem { Label("设置", systemImage: "gearshape.fill") }
            }
        }
    }
}

// 日志页：读 Documents/log/log.log 的尾部（文件可能很大，只读最后 64KB、
// 最多 200 行）。core 没有现成的日志接口，所以直接读文件。
struct LogsView: View {
    @State private var logText = "正在读取日志…"

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(logText)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationTitle("日志")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        loadLog()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task { loadLog() }
        }
    }

    private func loadLog() {
        let url = ServerBridge.documentsDirectory().appendingPathComponent("log/log.log")
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            logText = "暂无日志（log.log 还不存在，服务跑起来后才会有）。"
            return
        }
        defer { try? handle.close() }
        let maxBytes: UInt64 = 64 * 1024
        let fileSize = (try? handle.seekToEnd()) ?? 0
        let start = fileSize > maxBytes ? fileSize - maxBytes : 0
        try? handle.seek(toOffset: start)
        var data = Data()
        if let d = try? handle.readToEnd() {
            data = d ?? Data()
        }
        var text = String(data: data, encoding: .utf8) ?? ""
        // 从中间截断时丢掉第一行不完整的行。
        if start > 0, let firstNL = text.firstIndex(of: "\n") {
            text = String(text[text.index(after: firstNL)...])
        }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        logText = lines.suffix(200).joined(separator: "\n")
    }
}
