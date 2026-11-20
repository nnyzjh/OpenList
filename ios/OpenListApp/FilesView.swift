import SwiftUI

// 导航用的值：完整路径 + 文件本身（FileItem 自己不带路径）。
struct FileNav: Hashable {
    let path: String
    let item: FileItem
}

// 文件页的根：一个 NavigationStack，文件夹用路径字符串钻取，
// 文件用 FileNav 跳详情页。
struct FilesRootView: View {
    var body: some View {
        NavigationStack {
            FilesView(path: AppState.localMountPath)
                .navigationDestination(for: String.self) { path in
                    FilesView(path: path)
                }
                .navigationDestination(for: FileNav.self) { nav in
                    FileDetailView(path: nav.path, file: nav.item)
                }
        }
    }
}

struct FilesView: View {
    let path: String

    @EnvironmentObject var appState: AppState
    @State private var items: [FileItem] = []
    @State private var loading = false
    @State private var error: String?

    private var title: String {
        if path == AppState.localMountPath { return "本地文件" }
        return (path as NSString).lastPathComponent
    }

    var body: some View {
        List {
            if let error {
                Text(error)
                    .foregroundColor(.red)
                    .font(.footnote)
            }
            if items.isEmpty && !loading && error == nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text("这里还是空的")
                        .font(.headline)
                    Text("把文件放进“文件”App 里的 OpenList 文件夹，或在 WebDAV 页打开写入后用播放器/电脑传进来。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .listRowBackground(Color.clear)
            }
            ForEach(items) { item in
                if item.is_dir {
                    NavigationLink(value: path + "/" + item.name) {
                        FileRow(item: item)
                    }
                } else {
                    NavigationLink(value: FileNav(path: path + "/" + item.name, item: item)) {
                        FileRow(item: item)
                    }
                }
            }
        }
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await load(refresh: true) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .refreshable { await load(refresh: true) }
        .task { await load() }
    }

    private func load(refresh: Bool = false) async {
        loading = true
        error = nil
        do {
            let data = try await APIClient.shared.listFiles(path: path, refresh: refresh)
            items = data.content
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}

// 一行文件：图片有缩略图就显示缩略图（core 给的 /d/ 链接），
// 视频在 iOS 上没有缩略图（没有 ffmpeg），用默认图标，不承诺。
struct FileRow: View {
    let item: FileItem

    var body: some View {
        HStack(spacing: 12) {
            if item.isImage, !item.thumb.isEmpty,
               let url = APIClient.absoluteURL(item.thumb) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Image(systemName: item.iconName)
                            .foregroundColor(.accentColor)
                    }
                }
                .frame(width: 44, height: 44)
                .clipped()
                .cornerRadius(6)
            } else {
                Image(systemName: item.iconName)
                    .font(.title2)
                    .foregroundColor(item.is_dir ? .accentColor : .secondary)
                    .frame(width: 44, height: 44)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .lineLimit(1)
                if !item.is_dir {
                    Text(FileTypeHelper.readableSize(item.size))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            if item.is_dir {
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }
}
