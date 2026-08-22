# HSclubs iOS 开发与发布流程

## 当前产品边界

App 是学校入口和切换器，不是 Guiding Page 的原生重写：

1. 首页只有学校/域名搜索框和学校列表。
2. 选择学校后直接全屏打开该学校的已验证站点。
3. App 记住 `schoolId`，下次启动自动回到该学校。
4. 学校页面上只覆盖可拖动、贴边、自动收起的切换入口，不显示常驻顶栏。
5. App 不提供原生学校详情、趋势、分类筛选或社团管理页面。
6. 仅支持 iPhone。悬浮切换器和全屏学校站点是按单手手机操作设计和验证的，声明 iPad 会上架一套没人验证过的布局。

## 已完成

- SwiftUI 工程、Development/Staging/Production 配置及 App 图标。
- `GET /api/v1/schools` 网络层、2 MiB 响应限制、HTTPS/host 校验和错误映射。
- v1 目录容错解码：一个学校无效不会清空全部学校。
- 缓存优先加载、网络刷新、离线提示和下拉刷新。
- 使用不可变 `schoolId` 保存学校，支持旧 slug 的一次性唯一匹配迁移。
- 精简搜索首页、不可进入学校的状态说明和全屏 `WKWebView`。
- 同源导航边界、外部链接转 Safari、跨源脚本导航拒绝和端口校验。
- 悬浮切换器的拖动缩小、边缘吸附、展开、点击空白收起和超时收起。
- v1 跨仓库契约、fixtures、manifest 校验和上游同步 CI。
- 单元测试、UI 测试，以及 macOS 上执行 `xcodebuild test` 的 CI workflow。
- 隐私清单 `HSclubsApp/PrivacyInfo.xcprivacy`：不收集数据、不追踪，只申报 `UserDefaults` 的使用原因 `CA92.1`。
- `ITSAppUsesNonExemptEncryption = false`，上传时不再逐次回答出口合规问题。
- 版本号集中在 `Configurations/Version.xcconfig`，构建号可由命令行覆盖。

## 移动认证延期

移动认证实现保留在代码中，但 `Configurations/*.xcconfig` 的
`MOBILE_AUTH_ENABLED` 均为 `NO`。关闭时 App：

- 不在 WebView User-Agent 中声明移动认证能力。
- 不拦截 `/api/mobile-auth/start` 启动 `ASWebAuthenticationSession`。
- 不可能把一次性 code 或 OAuth token 带入 App 流程。

不要仅为了测试而在 Production 打开开关。启用前必须同时完成：

1. 获得生产 Apple Developer Team/App ID，并确认 Bundle ID `net.hsclubs.app`。
2. 在 `hsclubs.net` 发布包含真实 `TEAMID.net.hsclubs.app` 的 AASA。
3. 在真机验证 `applinks:hsclubs.net` 和 `.https` callback。
4. 所有真实学校通过 manifest、summary、PKCE、一次性 code 和 session completion 检查。
5. 完成真实 Google 账号 E2E，并接入 `.github/workflows/release-gate.yml`。
6. 验证取消、过期、错误 state、错误 PKCE、重复 code 和跨学校 callback。
7. 验证每个学校的 Cookie 会话相互隔离，并在退出 App 后按服务端期限保留。
8. 将 App 的 `MOBILE_AUTH_ENABLED` 和仓库变量 `HSCLUBS_MOBILE_AUTH_ENABLED` 一起改为 `true`。

仓库变量打开后，认证 prerequisites 和 Google E2E 会从 skipped 变成强制门禁；Google driver 未实现时会明确失败，不能出现假绿色。

## 日常开发流程

### 0. 版本号

`MARKETING_VERSION` 和 `CURRENT_PROJECT_VERSION` 只写在 `Configurations/Version.xcconfig`。上传 App Store Connect 时构建号必须递增，因此发布构建用命令行覆盖，而不是每次改文件：

```bash
xcodebuild archive ... CURRENT_PROJECT_VERSION=$BUILD_NUMBER
```

对外版本号变化时才修改 `MARKETING_VERSION`。

### 1. 同步与契约

```bash
git pull --ff-only
node scripts/check-contracts.mjs
node scripts/check-contract-sync.mjs
```

`contracts/v1` 只能从 Guiding Page 的 canonical contract 整体同步，不能在 App 仓库单独修改。

### 2. 修改工程

- 普通 Swift 文件直接在 Xcode 中修改。
- 增删 target、资源或 build setting 时先修改 `project.yml`，然后执行 `xcodegen generate`。
- 生成后检查 `HSclubs.xcodeproj` diff，避免丢失共享 Scheme 或测试 target。
- secret、证书、Provisioning Profile、测试账号和 Apple API key 不进入 Git。

### 3. 本地测试

在 Xcode 16.4+ 和 iOS 17.4+ Simulator 上执行：

```bash
xcodebuild test \
  -project HSclubs.xcodeproj \
  -scheme HSclubs \
  -configuration Development \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  CODE_SIGNING_ALLOWED=NO
```

重点回归：

- 搜索学校名和 host、空目录、网络失败、缓存回退和刷新。
- 选择保存、旧 slug 迁移、学校重命名及不兼容学校。
- WebView 同源/端口边界、普通外链和新窗口。
- 悬浮按钮拖动、贴边、展开、超时收起、切换学校和重启恢复。
- Dynamic Type、VoiceOver、深色模式以及小屏设备布局。

### 4. Pull Request 门禁

- `Contracts`：本地 v1 manifest 和 Guiding Page canonical manifest 一致。
- `iOS`：macOS runner 编译 App，并运行 unit/UI tests。
- PR 不请求真实学校或 Google，避免外部服务故障阻断普通开发。

## 发布流程

1. 确认 Production 的 API 地址、Bundle ID、版本号和认证开关。
   同时确认隐私清单仍与实际行为一致：新增任何 SDK、分析或 Required Reason API 都要更新
   `HSclubsApp/PrivacyInfo.xcprivacy`，否则会在上传后收到 Apple 的合规邮件。
2. 手动运行或触发 Release gate，核心真实学校检查必须通过。
3. 若移动认证仍关闭，确认相关 jobs 为 skipped，而不是失败后被忽略。
4. 若移动认证开启，认证 prerequisites 和 Google E2E 必须全部通过。
5. 在至少一台真实 iPhone 上验证首次启动、学校切换、重启恢复和外链。
6. 使用 TestFlight 验证签名、AASA、Cookie 生命周期和升级迁移。
7. 准备 App Store 图标、截图、描述、支持 URL、隐私政策和隐私申报。
   隐私政策 `https://hsclubs.net/privacy` 和支持页面 `https://hsclubs.net/support` 已由 Guiding Page
   提供，提交前确认两者仍返回 200，且内容与 App 实际行为一致。截图只需要 iPhone 尺寸。
8. Archive Production 构建，上传并提交审核。

## 发布完成标准

- `main` 的 Contracts 和 iOS CI 为绿色。
- Release gate 的核心学校检查为绿色。
- App 中没有 secret，ATS 未放宽，目录和 WebView 只接受验证过的 HTTPS origin。
- 选择恢复、缓存降级、导航边界和悬浮切换器均有自动化测试。
- 隐私申报与实际 SDK/网络行为一致。
- 隐私清单存在且与申报一致，构建号未与既有上传重复。
- 移动认证未满足全部前置条件时，运行时开关保持关闭。
