import ActivityKit
import Foundation

// 灵动岛 / 锁屏上常驻的保活 Live Activity 的属性。
// 主 App 和 Widget Extension 共用这份定义：
// 这个文件同时编进主 App target 和 OpenListLiveActivity target，
// 两边看到的是同一个类型，扩展才能认出主 App 发起的活动。
struct OpenListActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// 服务开始跑的时间（岛上用它显示已运行时长）。
        var startedAt: Date
    }

    /// 固定文案（不常变，写在属性里）。
    var title: String
}
