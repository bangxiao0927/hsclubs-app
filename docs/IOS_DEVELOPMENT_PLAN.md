# HSclubs iOS 开发流程

## 1. 现状与可行性检查

HSclubs Guiding Page 的浏览器端是 React 应用，通过相对地址 `GET /api/schools` 一次性获取页面数据。聚合服务负责验证学校来源、定时拉取摘要、保留最后一次成功结果并判断数据是否过期。因此，iOS 应用适合作为该公开 API 的另一个只读客户端。

生产接口检查结果：

- `https://hsclubs.net/api/schools` 可用，使用有效 HTTPS，返回 JSON。
- 顶层字段包括 `title`、`generatedAt`、`totals`、`schools`。
- 学校字段包括身份、官网、状态、社团数量、分类、时间、趋势历史和最后错误。
- 当前响应使用 `Cache-Control: no-store`。客户端仍可保存最近一次成功响应用于断网降级，但刷新时必须请求服务端新数据，并明确标注缓存时间。
- 原生 `URLSession` 不受浏览器 CORS 限制；仍需保持 App Transport Security，不能为方便而允许任意 HTTP。

### 当前 API 模型

```json
{
  "title": "HS Clubs",
  "generatedAt": "ISO-8601 timestamp",
  "totals": {
    "schools": 2,
    "clubs": 161,
    "checkedAge": "36 minutes ago"
  },
  "schools": [
    {
      "slug": "hsclubs",
      "siteUrl": "https://hsclubs.net",
      "host": "hsclubs.net",
      "demo": false,
      "location": { "lat": 37.359106, "lon": -122.067156 },
      "status": "live",
      "schoolName": "HS Clubs",
      "address": null,
      "clubCount": 106,
      "categories": [{ "name": "Academic", "count": 10 }],
      "publishedAge": "2 days ago",
      "changedAge": "2 days ago",
      "checkedAge": "36 minutes ago",
      "publishedAt": "ISO-8601 timestamp or null",
      "lastUpdatedAt": "ISO-8601 timestamp or null",
      "history": [{ "at": "ISO-8601 timestamp", "clubCount": 100 }],
      "trend": 6,
      "lastPolledAt": "ISO-8601 timestamp or null",
      "lastError": null
    }
  ]
}
```

不要让客户端因为新增字段而解码失败。未知 `status` 应映射为 `.unknown`，可选字段应保持可选。时间展示应优先根据 ISO-8601 字段和设备区域设置生成；服务端提供的 `*Age` 英文字符串可作为兼容回退，不应成为本地化的唯一来源。

## 2. 产品定义与设计

### 用户路径

1. 用户打开应用，先看到上次缓存或加载骨架。
2. 应用请求 `/api/schools`，成功后更新总览与目录。
3. 用户搜索学校名称/域名，选择一个或多个分类，并调整排序。
4. 用户打开学校详情，查看状态、分类数量与趋势。
5. 用户点击官网，在应用内 Safari 中访问已验证的 `siteUrl`。

### 与网页对齐的规则

- 搜索只匹配用户能看到的学校名称和域名，不匹配隐藏字段。
- 多个分类采用 AND 规则：学校必须同时包含所有已选分类。
- 名称排序使用显示名称；社团数量为空时排在有数据学校之后。
- 更新时间为空时排在最后，不能按 Unix epoch 伪装成有效时间。
- `demo: true` 必须始终显示“演示数据”，不能呈现为已批准的真实学校。
- `stale` 仍展示最后一次成功数据，同时解释数据可能过期；`no-data` 不显示虚构的 0。

### 首版页面

- `DirectoryView`：总览、搜索、筛选、排序和学校列表。
- `SchoolDetailView`：状态、地址、分类、数据时间、趋势图和官网按钮。
- 全局状态：首次加载、刷新中、空结果、无学校、网络失败、缓存降级。

先在 Figma 或低保真线框中确认 iPhone SE 尺寸和大号 Dynamic Type 下的布局，再实现视觉细节。颜色不能作为状态的唯一表达方式。

## 3. API 契约准备

在创建大量 UI 之前，先为 Guiding Page 补充以下契约工作：

1. 将当前 payload 固化成 JSON Schema 或 OpenAPI 文档，并保存真实匿名化 fixture。
2. 决定版本策略，例如保持 `/api/schools` 向后兼容，或新增 `/api/v1/schools`。
3. 明确字段是否可空、状态枚举、时间格式、最大响应大小和排序稳定性。
4. 给接口增加契约测试，保证 Web 和 iOS 所需字段不会被无意删除或改名。
5. 约定错误响应和维护模式；客户端不要解析服务端 HTML 错误页作为 JSON。

首版可以直接连接现有接口，但发布 App Store 版本前应完成契约版本化。iOS 审核后的旧客户端无法与服务端同步强制升级。

## 4. 工程初始化

1. 在 Xcode 创建 iOS App：Product Name `HSclubs`，Interface `SwiftUI`，Language `Swift`，最低 iOS 17。
2. 使用组织拥有的反向域名设置唯一 Bundle ID，例如 `net.hsclubs.app`；不要在签名确认前硬编码临时 ID。
3. 建立 `Development`、`Staging`、`Production` 三套 `.xcconfig`，通过 `API_BASE_URL` 注入服务地址。
4. 创建目录分层、单元测试 target 和 UI 测试 target。
5. 开启严格并发检查，将核心模型声明为 `Sendable`。
6. 提交共享 Scheme；证书、Provisioning Profile、API key 和个人 Team ID 不进入 Git。

推荐的依赖方向为 `Features -> Core`。网络、缓存不能反向依赖具体页面，View 不直接调用 `URLSession.shared`。

## 5. 数据层实现

按以下顺序实现，每一步都先写测试：

1. 定义 `PagePayload`、`School`、`Category`、`HistoryPoint` 和容错的 `SchoolStatus`。
2. 配置 `JSONDecoder` 的 ISO-8601 日期策略；为带小数秒和不带小数秒的时间添加兼容解析测试。
3. 定义 `SchoolsAPI` protocol，再实现基于 `URLSession` 的 `LiveSchoolsAPI`，便于 Preview 和测试注入 fake。
4. 将 HTTP 非 2xx、无效响应、解码失败、超时和离线映射成用户可理解、日志可诊断的错误。
5. 设置合理超时，限制接受的响应体大小，只接受 HTTPS 和预期 host。
6. 实现 `SchoolsCache`，原子写入最近一次成功 JSON及保存时间；不要缓存 Basic Auth、token 或其他秘密。
7. 实现 repository：先读取缓存供快速展示，再请求网络；网络成功替换缓存，失败时保留缓存并显示离线提示。

缓存只用于可用性，不用于绕过服务端新鲜度规则。应用前台激活或用户下拉刷新时可以重新请求，不需要后台高频轮询。

## 6. 功能实现顺序

### 里程碑 A：可浏览

- 完成网络层、模型、缓存和依赖注入。
- 实现总览、学校列表、加载/失败/空状态和下拉刷新。
- 验收：干净安装可加载生产或 staging fixture；断网重开可看到带时间标识的缓存。

### 里程碑 B：可查找

- 实现可测试的纯函数搜索、分类交集筛选和三种排序。
- 使用 `.searchable`，筛选状态使用 sheet 或适合小屏的导航页面。
- 验收：结果与网页规则一致；清除筛选后恢复全部学校；无匹配时提供重置入口。

### 里程碑 C：详情与趋势

- 实现学校详情、状态说明、分类数量、时间语义和 Swift Charts 趋势。
- 校验 `siteUrl` 为 `https` 且 host 一致后，通过全屏学校站点打开；跨 origin 导航交由系统浏览器处理。
- 验收：`nil` 数据不显示误导值；只有一个历史点时不声称存在趋势；演示学校标识明显。

### 里程碑 D：系统体验

- 支持深色模式、Dynamic Type、VoiceOver、Reduce Motion 和横竖屏布局。
- 为刷新失败增加可重试操作；刷新过程中保留已有内容，避免整页闪烁。
- 验收：Accessibility Inspector 无阻断问题，最大字体下主要操作不被裁切。

## 7. 测试策略

### 单元测试

- 完整、缺失可选字段、未知状态、错误日期和新增未知字段的 JSON 解码。
- 搜索大小写/空格处理、分类 AND 规则和所有排序的空值处理。
- HTTP 状态、超时、离线、超大响应、无效 JSON 与缓存回退。
- 日期和数字在至少英文、简体中文区域设置下的格式化。

### UI 测试

- 首次启动加载成功、加载失败后重试、无学校和无搜索结果。
- 搜索、筛选、排序、打开详情和打开学校官网。
- 缓存存在时的离线启动，以及 `stale`、`no-data`、`demo` 的展示。

### 持续集成

每次 Pull Request 执行：

```bash
xcodebuild test \
  -scheme HSclubs \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

CI 使用固定 fixture 和 stub，不依赖生产网络。可以另设非阻断 smoke job 检查生产 API 契约，并在契约漂移时告警。

## 8. 安全与隐私

- 应用只访问聚合 API 和用户主动打开的学校官网，不携带学校 registry、verification token 或运维凭据。
- 不调用受保护的 `/api/status`，不在应用中嵌入 Basic Auth 密码。
- 保持 ATS 默认限制，拒绝明文 HTTP；不要使用“允许任意加载”。
- 日志不记录完整响应、用户搜索词或可能在未来加入的敏感字段。
- 若首版不加入分析、广告、账号或推送，App Store 隐私申报应为“不收集数据”；最终申报仍须按实际 SDK 和行为复核。
- 准备公开隐私政策和支持页面，即使应用不收集个人数据也清楚说明网络请求和外部链接行为。

不建议首版做证书 pinning：它会增加证书轮换导致旧版应用断网的风险。标准 ATS、可信 CA 和正常的服务端 TLS 运维更适合当前公开只读数据。

## 9. 发布流程

1. 冻结 API 契约并完成 staging 端到端测试。
2. 确认应用名称、图标、截图、描述、关键词、年龄分级、支持 URL 和隐私政策 URL。
3. 在 App Store Connect 创建应用，配置自动签名和 TestFlight 内测组。
4. 先进行团队测试，再邀请小范围学校用户测试搜索、数据语义和外部链接。
5. 修复崩溃、无障碍和契约兼容问题，归档 Release 构建并提交审核。
6. 发布后监控崩溃与 API 可用性；服务端变更先通过契约测试和旧客户端 fixture 回归。

## 10. 完成标准

满足以下条件后可认为 MVP 可以发布：

- 核心流程在支持的最小 iOS 版本和当前版本通过。
- 首次加载、缓存降级、刷新、搜索、筛选、排序、详情和外链均有测试。
- VoiceOver 和最大 Dynamic Type 下可以完成核心流程。
- API 具有向后兼容策略，未知字段和未知状态不会导致整页失败。
- App 内不存在 secret，ATS 未放宽，隐私申报与实际行为一致。
- TestFlight 用户确认状态、时间、演示数据和过期数据的表达不会造成误解。
