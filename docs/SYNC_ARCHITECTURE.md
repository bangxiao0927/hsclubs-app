# HSclubs 同步与学校站点架构

## 核验结论

学校站点不是 Guiding Page 内嵌的网页壳，也不是由聚合服务统一托管的多租户页面。当前架构由三个边界清晰的项目组成：

1. [`HSclubs`](https://github.com/bangxiao0927/HSclubs) 是单所学校的完整参考实现。每所学校独立部署自己的 Vue 3 前端、Spring Boot API、数据库、Google OAuth 和域名。
2. [`hsclubs-guiding-page`](https://github.com/bangxiao0927/hsclubs-guiding-page) 保存经过人工登记和域名验证的学校列表，定时只读拉取每所学校的 `GET /api/summary`。
3. 本 iOS App 读取 Guiding Page 的 `GET /api/schools`，展示聚合摘要，并把完整浏览、登录和管理流程交回学校自己的已验证站点。

因此，“套用模板”是正确的描述，但它不是只有外观的壳。模板包含完整的公开目录和管理后端。学校复制参考实现后拥有自己的数据和权限边界，可以独立更新品牌、社团、成员与管理员，不依赖 Guiding Page 在线。

## 学校自主能力

参考学校站点当前包含：

- 公开社团目录、搜索、社团详情、日历和媒体内容。
- Google OAuth 登录和账号设置。
- 社团负责人管理页面 `/clubs/:id/admin`。
- 学校管理员页面 `/admin`。
- 创建、编辑、归档社团，以及审批成员申请的受保护 API。
- 匿名只读的 `GET /api/summary`，只发布学校身份、社团数量、分类和更新时间，不发布学生或管理员资料。

`https://hsclubs.net` 是该参考实现的当前部署实例。线上 `GET /api/summary` 与 Guiding Page 中的真实学校摘要一致。`demo-school.bangxiao.net` 是 Guiding Page 的演示 fixture，目前不是可用的独立学校站点，App 必须继续显示“Demo data”，不能把它视为获批学校。

## 数据流

```text
学校管理员 -> 学校自己的站点和数据库
                    |
                    | GET /api/summary（只读）
                    v
       Guiding Page 验证、轮询并缓存摘要
                    |
                    | GET /api/schools（只读）
                    v
                iOS App
                    |
                    | HTTPS 打开已验证 siteUrl
                    v
       学校自己的完整目录、登录和管理页面
```

Guiding Page 不写入学校，App 也不直接轮询每所学校或调用写接口。这样可以避免移动端与学校模板维护两套管理逻辑，并保证学校始终是自己数据的唯一来源。

## 新学校接入流程

1. 学校复制并独立部署 `HSclubs` 参考实现。
2. 配置学校名称、域名、数据库、OAuth 和管理员。
3. 确认同一 HTTPS origin 提供 `GET /api/summary`。
4. Guiding Page 操作员把学校加入私有 registry，并签发一次性验证 token。
5. 学校在同一 origin 发布 `/.well-known/hsclubs-site.txt`。
6. 验证通过后，Guiding Page 开始轮询；App 下次刷新 `/api/schools` 时自动出现该学校，不需要发布新版 App。

## App 同步规则

- App 的学校列表和摘要只以 `/api/schools` 为准。
- 未知 JSON 字段保持向后兼容；当前已同步 `location` 坐标字段。
- 学校名称为空时使用 registry 的 `slug`，与 Guiding Page 的显示回退一致。
- 只允许打开 `https` 且 host 与聚合数据一致的 `siteUrl`；学校站点使用全屏 Web 页面保留自身登录和管理会话，跨 origin 导航交给系统浏览器。
- 完整社团浏览、登录、成员和管理操作继续在学校站点完成。
- 选择学校后保存其 `slug`，下次启动在聚合数据验证该学校仍存在后自动进入。
- 原生主页只显示学校/域名搜索和学校列表；全屏学校站点不覆盖 host 标题栏，只保留可拖动、缩放并贴边的学校切换悬浮按钮，点击后向屏幕内侧展开操作，点击页面或超时自动收回。
- `python3 scripts/verify_guide_data.py` 可核对 Guiding Page 与每个真实学校 `/api/summary` 的身份、数量、分类和发布时间。
