import ActivityKit
import SwiftUI
import WidgetKit

// 灵动岛 / 锁屏上保活 Live Activity 的界面。
// 这是一个 Widget Extension：主 App 只负责启动/结束活动，
// 岛上和锁屏上长什么样由这里画（ActivityConfiguration）。
// 属性定义（OpenListActivityAttributes）在主 App 的文件里，
// 这个 target 也编它，两边是同一个类型。
@main
struct OpenListLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        OpenListLiveActivity()
    }
}

struct OpenListLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: OpenListActivityAttributes.self) { context in
            // 锁屏上的展开视图
            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.title)
                    .font(.headline)
                Text("已运行 \(context.state.startedAt, style: .timer)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .activityBackgroundTint(.clear)
            .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                // 展开的灵动岛：左右两边 + 底部
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.attributes.title)
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.startedAt, style: .timer)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("点一下回 App（不停服务）")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            } compactLeading: {
                // 岛上常驻的紧凑显示：左边一个服务器图标
                Image(systemName: "server.rack")
            } compactTrailing: {
                // 右边是已运行时长（从开始时间往上数）
                Text(context.state.startedAt, style: .timer)
                    .font(.caption2)
            } minimal: {
                // 岛上同时有多个活动时只留一个小图标
                Image(systemName: "server.rack")
            }
        }
    }
}
