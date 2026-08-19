# HSclubs iOS

> 中文翻译。英文版是原本：[README.md](README.md)。两份内容不一致时以英文版为准。

HSclubs iOS 是 [HSclubs Guiding Page](https://clubs.bangxiao.net) 的学校切换入口。用户搜索并选择已验证学校后，App 全屏打开该学校自己管理的站点。

> 当前状态：已完成精简学校选择器、生产 API、离线缓存、全屏学校站点、上次学校记忆和悬浮切换入口。后续实施流程见 [iOS 开发流程](docs/IOS_DEVELOPMENT_PLAN.md)。

## 页面检查结论

Guiding Page 是一个只读聚合页面。服务端定时从各学校的公开摘要拉取数据，iOS 客户端只需要读取聚合服务，不应直接轮询每个学校，也不需要复制 Node.js poller。

- 公开数据接口：`GET https://clubs.bangxiao.net/api/schools`
- 接口当前可通过 HTTPS 访问，返回 `200 application/json`
- 核心功能：按学校名或域名搜索、选择学校、记住上次选择、全屏打开学校站点和切换学校
- 学校主页由接口的 `siteUrl` 提供，应用在校验 HTTPS 和 host 后使用全屏 Web 页面打开；用户点击的外部链接交由系统浏览器处理，登录/OAuth 等跨源重定向和表单提交保留在 WebView 内以维持会话
- `/api/status` 是运维接口并受 Basic Auth 保护，不属于普通 iOS 客户端功能
- 数据是只读公开摘要，不包含登录、成员资料或社团管理功能

学校选择器使用 **SwiftUI 原生开发**。完整学校站点包含登录和管理会话，经 HTTPS/host 校验后作为全屏 `WKWebView` 交给学校自己的 Web 实现；悬浮切换按钮可拖动、贴边，点击后向屏幕内侧展开 `Switch School`，点击页面或稍等片刻会自动收回。

## 建议技术栈

- iOS 17+、Xcode 16+、Swift 6
- SwiftUI + Observation，使用轻量 MVVM/Feature 分层
- `URLSession` + `async/await` + `Codable`
- Swift Charts 展示学校社团数量趋势
- XCTest / Swift Testing，使用 URLProtocol stub 测试网络层
- 不引入第三方依赖作为首版默认方案

## MVP 范围

1. 加载并展示学校总数、社团总数和最近检查时间。
2. 展示学校卡片及 `live`、`stale`、`no-data`、`demo` 状态。
3. 按学校名称或域名搜索；按分类进行交集筛选。
4. 按名称、社团数量、更新时间排序。
5. 在详情页展示地址、分类、趋势和数据更新时间，并安全打开学校官网。
6. 支持下拉刷新、加载/空数据/失败状态以及最近一次成功数据的本地缓存。
7. 支持深色模式、Dynamic Type、VoiceOver 和 Reduce Motion。

MVP 不包含登录、推送、后台高频刷新、社团编辑、学校注册和运维状态页面。

## 预期目录

```text
HSclubsApp/
  App/                 # App 入口与依赖装配
  Core/
    Models/            # API Codable 模型
    Networking/        # APIClient、错误映射
    Persistence/       # 最近成功响应缓存
  Features/
    Directory/         # 总览、搜索、筛选、排序
    SchoolDetails/     # 学校详情与趋势
  DesignSystem/        # 颜色、字体和复用组件
HSclubsAppTests/
HSclubsAppUITests/
```

## 开始开发

1. 使用 Xcode 16 或更高版本打开 `HSclubs.xcodeproj`。
2. 选择共享的 `HSclubs` Scheme 和任意 iOS 17+ 模拟器后运行。
3. 修改 `project.yml` 后执行 `xcodegen generate` 重新生成工程。

命令行构建：

```bash
xcodebuild -project HSclubs.xcodeproj \
  -scheme HSclubs \
  -configuration Development \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

`Development`、`Staging`、`Production` 的服务地址分别由 `Configurations/` 下的 `.xcconfig` 注入。完整步骤、验收标准、测试和上架清单见 [`docs/IOS_DEVELOPMENT_PLAN.md`](docs/IOS_DEVELOPMENT_PLAN.md)。开始数据层编码前，建议先在 Guiding Page 服务端明确并版本化 `/api/schools` 的契约，避免 Web 与 iOS 各自维护的数据结构发生漂移。

App 只读取 Guiding Page 的聚合接口，不直接轮询学校。开发时可运行 `python3 scripts/verify_guide_data.py`，读取真实学校的权威 `/api/summary`，核对聚合接口中的身份、社团总数、分类和发布时间；演示学校使用保存的数据，因此会被明确跳过。学校独立部署和自主管理的边界见 [`docs/SYNC_ARCHITECTURE.md`](docs/SYNC_ARCHITECTURE.md)。

## 跨仓库契约

`contracts/v1/` 是学校模板、Guiding Page 和本 App 共用的 v1 契约，由
[hsclubs-guiding-page](https://github.com/bangxiao0927/hsclubs-guiding-page) 发布并原样复制到这里：
`/api/v1/summary`、`/.well-known/hsclubs-app.json`、`/api/v1/schools` 的 JSON Schema，固定 fixtures，
以及移动认证的 PKCE 与一次性 code 测试向量。说明见
[`contracts/v1/README.md`](contracts/v1/README.md)。

```bash
node scripts/check-contracts.mjs
```

该脚本逐文件校验本地副本与 `manifest.json` 的 sha-256 是否一致，并在 CI 中运行。契约只能在
Guiding Page 修改后整目录复制过来；直接改这里的副本，三个仓库就会悄悄各走各的。App 侧针对这些
fixtures 的解码测试随目录迁移一并加入。

## 许可证

本项目使用 [Apache License 2.0](LICENSE)。
