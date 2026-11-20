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
                SettingsView()
                    .tabItem { Label("设置", systemImage: "gearshape.fill") }
            }
        }
    }
}
