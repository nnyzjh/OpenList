import ActivityKit
import Foundation

// 在灵动岛 / 锁屏上常驻一个 Live Activity（“OpenList 运行中”）。
// 保活开始时启动，停服务时结束。点一下回 App，不停服务。
// iOS 16.2+ 才有这里用的 API（ActivityContent、带 pushType 的 request、
// 带 ActivityContent 的 update/end 都是 16.2 才加的；16.1 的老接口没有这些）。
// 部署目标是 16.0，调用方用 #available 守着。
// 注意：Live Activity 的界面（岛上长什么样）不在主 App 里，
// 在 Widget Extension（OpenListLiveActivity）里画。
@available(iOS 16.2, *)
enum LiveActivityManager {

    /// 启动 Live Activity。已经在跑就刷新一次（重计时），不重复建。
    /// 起不来也不报错、不打断保活（保活靠无声音频，岛只是个显示）。
    static func start() {
        let state = OpenListActivityAttributes.ContentState(startedAt: Date())
        if let activity = Activity<OpenListActivityAttributes>.activities.first {
            Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
            return
        }
        let attributes = OpenListActivityAttributes(title: "OpenList 运行中")
        do {
            _ = try Activity<OpenListActivityAttributes>.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {
            // 起不来就算了，不报错。
        }
    }

    /// 结束 Live Activity（岛上的常驻消失）。
    static func end() {
        for activity in Activity<OpenListActivityAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
