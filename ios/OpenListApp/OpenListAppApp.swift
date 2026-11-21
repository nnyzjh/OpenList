import SwiftUI

@main
struct OpenListAppApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .task {
                    await appState.startup()
                }
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .background:
                // 切后台：保活开着就不停服务（放无声音频 + 发一条“服务正在运行中”通知），
                // 关着（默认）就停服务。注意：即便保活开着，iOS 仍可能因内存压力
                // 或音频中断把 App 挂起，保活不是 100% 可靠。
                appState.onEnterBackground()
            case .active:
                Task { await appState.onEnterForeground() }
            default:
                break
            }
        }
    }
}
