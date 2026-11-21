import AppIntents
import Foundation

// 保活延长（App 切后台和快捷指令“延长常驻”共用）。
// 只在保活开关开着、服务在跑时延长：重开无声音频 + 刷新灵动岛 Live Activity。
// 服务没跑就不做（服务器开关只在 App 里，不进快捷指令）。
enum KeepAlive {
    static func extend() {
        guard UserDefaults.standard.bool(forKey: "backgroundKeepAlive"),
              ServerBridge.isRunning else { return }
        SilentAudioKeeper.shared.start()
        if #available(iOS 16.2, *) {
            LiveActivityManager.start()
        }
    }
}

// 快捷指令动作“延长常驻”：延长一次 OpenList 保活。
// 只延长保活（重开无声音频 + 刷新灵动岛的 Live Activity），
// 不开关服务器（服务器开关只在 App 里）。
// 用在“快捷指令”App 的自动化里（比如每天 08:00 / 16:00 / 00:00 跑一次），
// 让保活和岛上的常驻一直续着。服务没在跑、保活开关没开时跑了也没用。
struct ExtendKeepAliveIntent: AppIntent {
    static var title: LocalizedStringResource = "延长常驻"
    static var description = IntentDescription("延长一次 OpenList 保活：重开无声音频，刷新灵动岛的 Live Activity。只在服务已经在跑、保活开关开着时有用。")

    func perform() async throws -> some IntentResult {
        KeepAlive.extend()
        return .result()
    }
}
