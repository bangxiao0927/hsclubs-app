# HSclubs iOS

HSclubs iOS 是 [HSclubs Guiding Page](https://clubs.bangxiao.net) 的原生 iOS 客户端，目标是让用户在 iPhone 上浏览、搜索和筛选已验证学校的社团目录。

> 当前状态：规划阶段。本仓库暂不包含可运行的 Xcode 工程，开发前的技术检查和实施流程见 [iOS 开发流程](docs/IOS_DEVELOPMENT_PLAN.md)。

## 页面检查结论

Guiding Page 是一个只读聚合页面。服务端定时从各学校的公开摘要拉取数据，iOS 客户端只需要读取聚合服务，不应直接轮询每个学校，也不需要复制 Node.js poller。

- 公开数据接口：`GET https://clubs.bangxiao.net/api/schools`
- 接口当前可通过 HTTPS 访问，返回 `200 application/json`
- 核心功能：总览、学校列表、按学校名或域名搜索、分类筛选、排序、学校详情、数据状态与趋势
- 学校主页由接口的 `siteUrl` 提供，应用应使用 `SFSafariViewController` 或系统浏览器打开
- `/api/status` 是运维接口并受 Basic Auth 保护，不属于普通 iOS 客户端功能
- 数据是只读公开摘要，不包含登录、成员资料或社团管理功能

建议使用 **SwiftUI 原生开发**，而不是把网页直接封装进 `WKWebView`。原生方案在离线缓存、无障碍、动态字体、导航、测试和 App Store 体验上更可靠。`WKWebView` 仅适合验证想法的短期原型。

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

完整步骤、验收标准、测试和上架清单见 [`docs/IOS_DEVELOPMENT_PLAN.md`](docs/IOS_DEVELOPMENT_PLAN.md)。开始编码前，建议先在 Guiding Page 服务端明确并版本化 `/api/schools` 的契约，避免 Web 与 iOS 各自维护的数据结构发生漂移。

## 许可证

本项目使用 [Apache License 2.0](LICENSE)。
