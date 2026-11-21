import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var failedUsername = ""
    @State private var failedPassword = ""

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
                // 一个账号：用户名和密码都能改，不强制是 admin，
                // 初始是 admin / admin。如果在管理页改过账号，
                // 在这里填入新的用户名和密码点“保存账号”，
                // 直接改掉 core 里的账号（不用旧密码，不删数据），再重试。
                Text("如果在管理页改过账号，在这里填入新的用户名和密码，点“保存账号”直接改掉（不用旧密码，不删数据），再点重试。")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                TextField("用户名", text: $failedUsername)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                TextField("密码", text: $failedPassword)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                Button("保存账号并重试") {
                    Task {
                        if await appState.setAdminAccount(username: failedUsername, password: failedPassword) {
                            failedUsername = ""
                            failedPassword = ""
                            await appState.retryStartup()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(failedUsername.isEmpty || failedPassword.isEmpty)
                if let err = appState.lastError {
                    Text(err)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
                Button("重试") {
                    Task { await appState.retryStartup() }
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .onAppear {
                // 失败页的账号框默认填当前存着的账号（只在空着的时候填）。
                if failedUsername.isEmpty { failedUsername = appState.adminUsername }
                if failedPassword.isEmpty { failedPassword = appState.adminPassword }
            }
        case .idle:
            VStack(spacing: 16) {
                Image(systemName: "power")
                    .font(.largeTitle)
                    .foregroundColor(.blue)
                Text("服务未启动")
                    .font(.headline)
                Text("自动运行关着，打开 App 不会自动启动服务。")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                Button("启动服务") {
                    Task { await appState.startup() }
                }
                .buttonStyle(.borderedProminent)
                Text("想以后打开就自动启动，去设置里打开“自动运行”。")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
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
// 最多 200 条）。core 没有现成的日志接口，所以直接读文件。
// 日志是 logrus 格式：time="..." level=info msg="..."（文件里可能带 ANSI
// 颜色码，先去掉再解析）。每条前面标出状态：error 红字、warn 橙字、
// info/debug 灰字，一眼看出哪行出问题。堆栈等多行内容并到上一条下面。
struct LogsView: View {
    @State private var entries: [LogEntry] = []
    @State private var rawText = "正在读取日志…"
    @State private var copied = false

    var body: some View {
        NavigationStack {
            List(entries) { entry in
                HStack(alignment: .top, spacing: 8) {
                    Text(entry.level.label)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(entry.level.color)
                        .frame(width: 44, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.message)
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)
                        if !entry.timestamp.isEmpty {
                            Text(entry.timestamp)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                .listRowBackground(entry.level.rowBackground)
            }
            .listStyle(.plain)
            .navigationTitle("日志")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            UIPasteboard.general.string = rawText
                            copied = true
                            Task {
                                try? await Task.sleep(nanoseconds: 1_500_000_000)
                                copied = false
                            }
                        } label: {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        }
                        Button {
                            loadLog()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .task { loadLog() }
        }
    }

    private func loadLog() {
        let url = ServerBridge.documentsDirectory().appendingPathComponent("log/log.log")
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            entries = []
            rawText = "暂无日志（log.log 还不存在，服务跑起来后才会有）。"
            return
        }
        defer { try? handle.close() }
        let maxBytes: UInt64 = 64 * 1024
        let fileSize = (try? handle.seekToEnd()) ?? 0
        let start = fileSize > maxBytes ? fileSize - maxBytes : 0
        try? handle.seek(toOffset: start)
        var data = Data()
        if let d = try? handle.readToEnd() {
            data = d
        }
        var text = String(data: data, encoding: .utf8) ?? ""
        // 从中间截断时丢掉第一行不完整的行。
        if start > 0, let firstNL = text.firstIndex(of: "\n") {
            text = String(text[text.index(after: firstNL)...])
        }
        rawText = text
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        entries = Array(LogEntry.parse(lines: lines).suffix(200))
    }
}

// 一条日志：级别 + 时间 + 内容（可能多行，堆栈会并进来）。
struct LogEntry: Identifiable {
    let id = UUID()
    let level: LogLevel
    let timestamp: String
    var message: String

    enum LogLevel {
        case info, warn, error, debug

        var label: String {
            switch self {
            case .info: return "info"
            case .warn: return "warn"
            case .error: return "error"
            case .debug: return "debug"
            }
        }

        var color: Color {
            switch self {
            case .info: return .secondary
            case .warn: return .orange
            case .error: return .red
            case .debug: return .secondary
            }
        }

        /// 整行的底色：报错整行淡红底，警告淡橙底，扫一眼就看到问题。
        var rowBackground: Color {
            switch self {
            case .error: return Color.red.opacity(0.15)
            case .warn: return Color.orange.opacity(0.12)
            case .info, .debug: return Color.clear
            }
        }
    }

    /// 把日志行解析成条目。带 level= 的行开一条新记录，
    /// 不带的（堆栈、Go 标准库输出）并到上一条的内容里。
    static func parse(lines: [String]) -> [LogEntry] {
        var out: [LogEntry] = []
        for raw in lines {
            let line = stripANSI(raw)
            guard let level = level(of: line) else {
                // 续行：并到上一条。
                if !out.isEmpty, !line.trimmingCharacters(in: .whitespaces).isEmpty {
                    out[out.count - 1].message += "\n" + line
                }
                continue
            }
            out.append(LogEntry(
                level: level,
                timestamp: field(named: "time", in: line) ?? "",
                message: field(named: "msg", in: line) ?? line
            ))
        }
        return out
    }

    /// 去掉 ANSI 颜色码（logrus 写文件时也带颜色）。
    private static func stripANSI(_ s: String) -> String {
        s.replacingOccurrences(
            of: "\u{1B}\\[[0-9;]*m",
            with: "",
            options: .regularExpression
        )
    }

    /// 从 `level=info` / `level=error` 里读级别。
    private static func level(of line: String) -> LogLevel? {
        guard let range = line.range(of: "level=") else { return nil }
        let rest = line[range.upperBound...]
        let word = rest.prefix(while: { $0.isLetter })
        switch word {
        case "info": return .info
        case "warning": return .warn
        case "error", "fatal", "panic": return .error
        case "debug", "trace": return .debug
        default: return nil
        }
    }

    /// 从 `key="..."` 里取值（处理 \" 转义）；没引号就取到下一个空格。
    private static func field(named key: String, in line: String) -> String? {
        guard let range = line.range(of: key + "=") else { return nil }
        var rest = line[range.upperBound...]
        if rest.hasPrefix("\"") {
            rest = rest.dropFirst()
            var out = ""
            var idx = rest.startIndex
            while idx < rest.endIndex {
                let ch = rest[idx]
                if ch == "\\" {
                    let next = rest.index(after: idx)
                    if next < rest.endIndex {
                        out.append(rest[next])
                        idx = rest.index(after: next)
                        continue
                    }
                }
                if ch == "\"" { return out }
                out.append(ch)
                idx = rest.index(after: idx)
            }
            return out
        }
        let word = rest.prefix(while: { !$0.isWhitespace })
        return word.isEmpty ? nil : String(word)
    }
}
