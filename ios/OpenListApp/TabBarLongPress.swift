import ObjectiveC
import SwiftUI
import UIKit

// 在 TabView 底栏上加长按手势：长按“设置”那个 tab 图标就开关开发者模式
//（开发者模式开着才显示删除按钮，比如应用密钥的删除）。
// SwiftUI 的 TabView 不直接支持给 tab 栏图标加手势，
// 所以这里用一个透明的 UIView 找到底层的 UITabBar，
// 给它挂一个 UILongPressGestureRecognizer。
// 放在 TabView 的 background 里，随 TabView 一起出现/消失。
struct TabBarLongPress: UIViewRepresentable {
    /// 底栏一共几个 tab。
    var tabCount: Int
    /// “设置”是第几个 tab（从 0 数）。
    var settingsIndex: Int
    /// 长按“设置” tab 时调。
    var onSettingsLongPress: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        // 视图刚建好时还没进层级、UITabBar 也未必建好，
        // 晚一点再挂手势，挂不上就多试几次。
        attachLater(view: view, context: context, attempt: 0)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // 视图更新时也试一次（比如 TabView 刚建好那次 make 还没挂上）。
        attach(view: uiView, context: context)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onSettingsLongPress: onSettingsLongPress, tabCount: tabCount, settingsIndex: settingsIndex)
    }

    private func attachLater(view: UIView, context: Context, attempt: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + Double(attempt) * 0.5) {
            if attach(view: view, context: context) { return }
            if attempt < 5 {
                attachLater(view: view, context: context, attempt: attempt + 1)
            }
        }
    }

    /// 找到 UITabBar 并挂长按手势。挂上了返回 true，
    /// 已经挂过或还没找到返回 false。
    @discardableResult
    private func attach(view: UIView, context: Context) -> Bool {
        guard let tabBar = findTabBar(from: view) else { return false }
        // 一个 tabBar 只挂一次（视图重建时不再重复挂，
        // 否则长按会触发多次、开发者模式开关两次等于没动）。
        if objc_getAssociatedObject(tabBar, &attachedKey) != nil { return true }
        objc_setAssociatedObject(tabBar, &attachedKey, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        let gr = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handle(_:)))
        gr.minimumPressDuration = 0.6
        // 不取消触摸：长按“设置” tab 时 tab 照常选中，
        // 同时触发开发者模式开关。
        gr.cancelsTouchesInView = false
        tabBar.addGestureRecognizer(gr)
        context.coordinator.tabBar = tabBar
        return true
    }

    /// 从一个视图出发，往上找到根视图，再往下找 UITabBar。
    private func findTabBar(from view: UIView) -> UITabBar? {
        var root: UIView = view
        while let parent = root.superview { root = parent }
        return findTabBar(in: root)
    }

    private func findTabBar(in view: UIView) -> UITabBar? {
        if let tabBar = view as? UITabBar { return tabBar }
        for sub in view.subviews {
            if let found = findTabBar(in: sub) { return found }
        }
        return nil
    }

    class Coordinator: NSObject {
        var onSettingsLongPress: () -> Void
        var tabCount: Int
        var settingsIndex: Int
        weak var tabBar: UITabBar?

        init(onSettingsLongPress: @escaping () -> Void, tabCount: Int, settingsIndex: Int) {
            self.onSettingsLongPress = onSettingsLongPress
            self.tabCount = tabCount
            self.settingsIndex = settingsIndex
        }

        @objc func handle(_ gr: UILongPressGestureRecognizer) {
            guard gr.state == .began, let tabBar = tabBar else { return }
            // tab 栏的项是均匀排开的，按横坐标算落在第几个上。
            let x = gr.location(in: tabBar).x
            let width = tabBar.bounds.width
            guard width > 0 else { return }
            let index = Int(x / (width / CGFloat(tabCount)))
            if index == settingsIndex {
                onSettingsLongPress()
            }
        }
    }
}

/// 标记“这个 tabBar 已经挂过长按手势”的关联对象 key。
private var attachedKey: UInt8 = 0
