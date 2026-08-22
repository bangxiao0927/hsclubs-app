# HSclubs iOS

> 中文翻译。英文版是原本：[README.md](README.md)。两份内容不一致时以英文版为准。

HSclubs iOS 是 [HSclubs Guiding Page](https://hsclubs.net) 的学校切换入口。用户搜索并选择已验证学校后，App 全屏打开该学校自己管理的站点。

> 当前状态：已完成精简学校选择器、生产 API、离线缓存、全屏学校站点、上次学校记忆和悬浮切换入口。后续实施流程见 [iOS 开发流程](docs/IOS_DEVELOPMENT_PLAN.md)。

## 页面检查结论

Guiding Page 是一个只读聚合页面。服务端定时从各学校的公开摘要拉取数据，iOS 客户端只需要读取聚合服务，不应直接轮询每个学校，也不需要复制 Node.js poller。

- App 目录接口：`GET https://hsclubs.net/api/v1/schools`
- 接口当前可通过 HTTPS 访问，返回 `200 application/json`
- 核心功能：按学校名或域名搜索、选择学校、记住上次选择、全屏打开学校站点和切换学校
- 学校主页由目录提供，应用校验完整 HTTPS origin 后使用全屏 Web 页面打开；同源导航留在 WebView，普通外部链接交给 Safari，非用户触发的跨源导航会被拒绝
- `/api/status` 是运维接口并受 Basic Auth 保护，不属于普通 iOS 客户端功能
- 目录是公开只读数据，不包含成员资料或社团管理数据

学校选择器使用 **SwiftUI 原生开发**。完整学校站点包含登录和管理会话，经 HTTPS/host 校验后作为全屏 `WKWebView` 交给学校自己的 Web 实现；悬浮切换按钮可拖动、贴边，点击后向屏幕内侧展开 `Switch School`，点击页面或稍等片刻会自动收回。

## 建议技术栈

- iOS 17+、Xcode 16+、Swift 6
- 仅支持 iPhone；悬浮切换器和全屏学校站点按单手手机操作设计
- SwiftUI + Observation，使用轻量 MVVM/Feature 分层
- `URLSession` + `async/await` + `Codable`
- XCTest / Swift Testing，使用 URLProtocol stub 测试网络层
- 不引入第三方依赖作为首版默认方案

## MVP 范围

1. 原生首页只显示一个学校/域名搜索框和已验证学校列表。
2. 选择学校后直接在全屏 `WKWebView` 打开已验证 origin。
3. 使用不可变 `schoolId` 记住选择，并在下次启动时自动打开。
4. 提供可拖动、贴边的悬浮学校切换入口，不显示常驻顶栏。
5. 支持下拉刷新、加载/空数据/失败状态和最近一次成功数据缓存。
6. 单个错误学校不会导致整个目录失败，不兼容学校可见但不能进入。

App 不收集任何数据，并随包提供隐私清单：不追踪、不收集数据，只申报用于记住所选学校的
`UserDefaults`（原因 `CA92.1`）。

移动认证代码已经存在，但所有构建配置默认关闭。生产 Apple App ID、AASA、全部真实学校检查和真机 E2E 完成前不会启用。推送、后台轮询、原生学校详情、社团编辑、学校注册和运维状态页面不属于 MVP。

## 预期目录

```text
HSclubsApp/
  App/                 # App 入口与依赖装配
  Core/
    Models/            # API Codable 模型
    Networking/        # APIClient、错误映射
    Persistence/       # 最近成功响应缓存
  Features/
    Directory/         # 精简学校/域名搜索和选择
    SchoolDetails/     # 全屏学校站点与悬浮切换器
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

`Development`、`Staging`、`Production` 的服务地址和移动认证开关由 `Configurations/` 下的 `.xcconfig` 注入。完整步骤、验收标准、测试和上架清单见 [`docs/IOS_DEVELOPMENT_PLAN.md`](docs/IOS_DEVELOPMENT_PLAN.md)。App 使用固定且容错解码的 v1 目录，不依赖浏览器页面 payload。

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
