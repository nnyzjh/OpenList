import SwiftUI

// 单个文件的详情页：预览 + 直链。
// 图片：用 core 给的 raw_url 原图预览。
// 视频：iOS 上没有视频缩略图，也不内置播放器，
//       给出直链和去 WebDAV 的提示，用 VidHub/Infuse 打开。
struct FileDetailView: View {
    let path: String
    let file: FileItem

    @State private var detail: FileDetail?
    @State private var error: String?
    @State private var copied: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let error {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.footnote)
                }
                preview
                info
                actions
            }
            .padding()
        }
        .navigationTitle(file.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    @ViewBuilder
    private var preview: some View {
        if file.isImage {
            if let detail, !detail.raw_url.isEmpty,
               let url = APIClient.absoluteURL(detail.raw_url) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                    case .failure:
                        Label("图片打不开", systemImage: "exclamationmark.triangle")
                    default:
                        ProgressView()
                    }
                }
                .frame(maxWidth: .infinity)
                .cornerRadius(8)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        } else if file.isVideo {
            VStack(spacing: 8) {
                Image(systemName: "film.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("视频不在本 App 里播")
                    .font(.headline)
                Text("用 VidHub / Infuse 这类播放器打开：先在 WebDAV 页打开开关，再在播放器里添加 WebDAV 源；也可以直接复制下面的直链。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
        } else {
            VStack(spacing: 8) {
                Image(systemName: file.iconName)
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text(file.name)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 6) {
            LabeledRow(label: "大小", value: FileTypeHelper.readableSize(file.size))
            if !file.modified.isEmpty {
                LabeledRow(label: "修改时间", value: FileTypeHelper.shortDate(file.modified))
            }
            LabeledRow(label: "路径", value: path)
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            if let detail, !detail.raw_url.isEmpty {
                Button {
                    UIPasteboard.general.string = detail.raw_url
                    copied = true
                } label: {
                    Label(copied ? "已复制" : "复制直链", systemImage: "link")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                Text(detail.raw_url)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
        }
    }

    private func load() async {
        do {
            detail = try await APIClient.shared.getFile(path: path)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct LabeledRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.footnote)
    }
}
