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
                // 切后台：停掉服务（iOS 约 2 分钟后也会把 App 挂起，
                // 服务本来就活不过后台，这是系统限制，不是 bug）。
                appState.shutdown()
            case .active:
                Task { await appState.resume() }
            default:
                break
            }
        }
    }
}
