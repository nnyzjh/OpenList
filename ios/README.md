# OpenList iOS 自编译版（基础版）

自己编的 OpenList iPhone 版，只做基础版：能用，再谈加功能。

- 核心：OpenList v4.2.9（2026-10-24，tag `v4.2.9`，commit `0497ee85`）
- 壳：原生 Swift（SwiftUI），很薄，只做启动 + 五个验收项
- 核心一个文件都没改；新增的只有 `mobile/`、`ios/`、`.github/workflows/build-ios.yml`

## 来源与署名

- 核心代码来自 OpenListTeam/OpenList，许可证 AGPL-3.0（见仓库根目录 `LICENSE`），
  作者 The OpenList Projects Contributors。署名和许可证都在原位，没动过。
- 壳（`ios/`）和 wrapper（`mobile/`）是新写的。
- 改了核心源码再分发的话，按 AGPL 得公开改过的核心源码；本版没改核心。

## 架构

```
Swift 壳 (ios/OpenListApp)  --MobileSetDataDir/Init/Start-->  Go 核心 (mobile 包)
        |  HTTP API  http://127.0.0.1:5244                         |
        +-- /api/fs/list, /api/fs/get, /api/me, /api/public/* ----+
```

- 核心是 Go 服务，壳用 gomobile 把它编成 `OpenListCore.xcframework` 嵌进 App。
- 监听地址和端口按 OpenList 自己的默认：`0.0.0.0:5244`，没改过。
  （苹果在真机上自己回退到 127.0.0.1；真报错了再说。）
- 壳永远走 HTTP API 读写，不直接读磁盘文件，出错时拿到的是核心报的原话。

## 五条验收标准是怎么实现的

1. **本地存储能用** —— 启动时在 Documents 下建 `Files` 文件夹，
   没有 `/local` 存储就调 `POST /api/admin/storage/create`
   （Local 驱动，`root_folder_path` = Documents/Files）新建一个；
   文件列表一律走 `POST /api/fs/list`。
   根目录不用 Documents 本身，不然 config.json、data.db 也会出现在列表里。
2. **WebDAV 开关在原生界面** —— WebDAV 页两个开关，改用户权限的
   bit 8（读）/ bit 9（写），经 `POST /api/admin/user/update` 写回；
   状态从 `GET /api/me` 读。默认管理员读开写关。
3. **显示版本号** —— 设置页显示 `GET /api/public/settings` 里的
   `version`（如 `v4.2.9 (Commit: …) - Frontend: … - Build at: …`），
   拿不到时退回编译进核心的版本号。
4. **能给 VidHub / Infuse 用** —— WebDAV 页给地址
   `http://127.0.0.1:5244/dav`（同一 Wi-Fi 下还有局域网地址）+ 账号，
   都能一键复制；单文件页给 `/d/` 直链（`POST /api/fs/get` 的 `raw_url`）。
   伪 Emby 不走（v4.2.10 源码里视频依然拿不到地址）。
5. **图片预览能用** —— 列表用 `thumb` 字段（只有图片有效），
   点开用 `raw_url` 原图预览。视频缩略图在 iOS 上做不了（没有 ffmpeg），
   视频用默认图标，不承诺。

另外：管理员密码首次启动随机生成，只存在 iOS 钥匙串里；
首次启动核心用这个密码自动建好 admin 账号（环境变量方式），
不用再走网页安装向导。

## 编译（给操作的人）

1. 新建一个 GitHub 仓库（公开的就行，公开仓库的 Actions 免费额度不限），
   把这个目录的全部内容传上去。
2. Actions 页 → Build iOS → Run workflow，手动点一次。
   只用手动触发，别 push 自动跑；Mac 机器经常排不上队，不要频繁重试。
3. 跑完后 artifact `openlist-ios-unsigned-ipa` 里是未签名的 .ipa（保留 7 天）。
4. 签名是下一步：用自己的证书 + 描述文件签（另有 ipa-signer 流程），
   签好才能装到手机上。

工作流做的事（`.github/workflows/build-ios.yml`）：
拉前端 v4.2.9 的包 → `gomobile bind` 出 xcframework →
`xcodebuild`（`CODE_SIGNING_ALLOWED=NO`）编出未签名的 .app → 打成 .ipa。

注意：前端包不是可选的。没有 `public/dist/index.html`，
核心启动时会直接 FATA 退出（本地实测过：`index.html not exist`）。
所以工作流里拉前端那一步必须成功，失败了整个构建就停，不能继续。

## 改之前先知道

- 包名（bundle id）现在是占位符 `com.openlist.ios`，
  真签名之前改成自己的（比如自己的反域名），描述文件要和它对应。
- 切后台约 2 分钟后服务会停（iOS 的限制，任何 App 都一样）；
  用的时候保持 App 在前台。
- 免费证书签的包 7 天过期，要重签。
- 视频缩略图在 iOS 上没有；App Store 上架要过审。

## 本地验证过什么 / 没验证过什么

已验证（这台 Linux 机器上）：
- `mobile/` 包 `go vet` 通过。
- 全部 11 个 Swift 文件语法解析通过（tree-sitter）。
- `project.pbxproj` 能被解析，目标、三个构建阶段、文件引用都对得上；
  唯一“缺失”的引用是 `OpenListCore.xcframework`，它是工作流现场编的。
- 工作流 YAML 能解析，9 个步骤。
- 核心在 Linux 上实际跑起来过，API 全流程用 curl 测过：
  首次建 admin、登录、`/api/me`、建 Local 存储、列文件、取直链、
  WebDAV PROPFIND、`/api/public/settings` 的版本号。

没验证过（这里没有 Mac 和 iPhone）：
- gomobile bind 出 xcframework 是否一次成功。
- xcodebuild 是否一次编过。
- 真机上 App 是否能启动、登录、列文件、接 VidHub。
- 首次跑通以真机为准，上面任何一步报错都先看日志再改。

## 新增 / 改动的文件

新增（核心文件一个没动）：
- `mobile/mobile.go` —— wrapper：SetDataDir / SetAdminPassword / Init /
  Start / Shutdown / IsRunning / Version
- `ios/OpenListApp/*.swift`（11 个）—— 壳
- `ios/OpenListApp/Info.plist`、`ios/OpenListApp/Assets.xcassets/`（含占位图标）
- `ios/OpenListApp/OpenListApp.xcodeproj/project.pbxproj`
  （由 `ios/gen_xcodeproj.py` 生成，改工程请改生成器再重新生成）
- `ios/gen_xcodeproj.py` —— 工程文件生成器
- `.github/workflows/build-ios.yml` —— 编译工作流
- `ios/README.md` —— 本文件
