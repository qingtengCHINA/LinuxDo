# LinuxDo — 原生 iOS 客户端

LinuxDo 论坛 (linux.do) 的原生 iOS 客户端，基于 [fluxdo](https://github.com/fluxdo/fluxdo) Flutter 版本做 1:1 移植，使用 SwiftUI + Swift 6 重写。

## 项目需求

基于 fluxdo-main Flutter 项目的完整功能和体验，制作原生 iOS 客户端：

- **完全移植** fluxdo 的所有页面和交互到原生 iOS
- **字体采用衬线体** (Font.Design.serif) 作为设计特色
- **高效简洁的代码设计**，杜绝内存泄漏
- **Swift 6 MainActor 隔离模式**，零第三方依赖
- **iOS 17.6+** 部署目标

### 核心体验优先级

1. 话题浏览 → 2. 话题详情 → 3. 回复 → 4. 搜索 → 5. 通知 → 6. 书签 → 7. 个人中心

---

## 已完成

### 基础架构
- [x] 项目骨架 (Models/Services/ViewModels/Views/Utils 分层)
- [x] Swift 6 `@MainActor` 隔离全局生效
- [x] `PBXFileSystemSynchronizedRootGroup` — 文件自动检测，无需手动添加到 Xcode
- [x] `DesignTypography` 衬线字体系统
- [x] `Color(hex:)` 扩展 + `String.strippingDiscourseMarkup()` HTML 清洗管道

### 认证系统
- [x] `SessionStore` + `CookieBridge` — WKWebView Cookie 同步到 URLSession
- [x] `CSRFManager` — 自动获取/刷新 CSRF Token
- [x] `LoginView` — WKWebView 内嵌登录页
- [x] 登录检测：`<meta name="current-username">` + `Discourse.User` JS 轮询

### 网络层
- [x] `HTTPClient` — 统一 GET/POST/POST_FORM/PUT/PUT_FORM/DELETE/DELETE_VOID
- [x] `postForm()` / `putForm()` — 所有 Discourse 写操作使用 `application/x-www-form-urlencoded`
- [x] `deleteVoid()` / `putVoid()` — 通过 `perform()` 获得 CSRF 重试能力
- [x] Cookie/CSRF/UA 自动注入 + `Sec-Fetch-*` 头（防 Cloudflare 拦截）
- [x] BAD CSRF 自动刷新重试（所有方法，因为 BAD CSRF = 请求未执行）
- [x] `CSRFManager` — 使用 `HTTPClient.shared.session` 获取 token（共享 Cookie）
- [x] 401 自动登出处理（403 BAD CSRF 不登出）

### 数据模型 (对齐 fluxdo)
- [x] `Topic` — fancyTitle, bumpedAt, archetype, imageUrl, pinnedGlobally, isPrivateMessage
- [x] `TopicDetail` — bookmarked, bookmarkableID 字段 (书签跟踪)
- [x] `PostStream` / `Post` — var 可变 (支持分页合并)
- [x] `Post` — 完整字段 (flair, reactions, accepted answer, hidden, deleted 等)
- [x] `Tag` — 兼容字符串和对象两种格式
- [x] `Badge / UserBadge / UserBadgeResponse`
- [x] `SearchResult / SearchPost / SearchUser / GroupedSearchResult` (Optional 容错解码)
- [x] `SearchCategory`
- [x] `SearchOrder / SearchStatus` 枚举 (搜索筛选)
- [x] `Bookmark / BookmarkListResponse`
- [x] `NotificationType` 枚举 — 30+ 类型，图标+颜色映射
- [x] `DiscourseCategory` — 分类列表
- [x] `DiscourseUser / UserSummary` — 用户资料+统计数据
- [x] `PostActionResponse` — 合并到 PaginatedResponse.swift，所有字段 Optional
- [x] `Draft` 相关模型 (DraftService)

### 服务层
- [x] `TopicService` — latest/top/category/tag/detail/search
- [x] `UserService` — profile/summary/badges/userTopics/toggleFollow (.shared 单例)
- [x] `CategoryService` — 分类列表
- [x] `NotificationService` — 通知列表+标记已读
- [x] `BookmarkService` — CRUD + `findBookmarkID()` 回退查找 + `fetchExistingBookmark()` 软成功
- [x] `SearchService` — 关键词搜索 + 分类/排序/状态筛选
- [x] `PostService` — 点赞/回复/删除/取消点赞 (全部 form-encoded)
- [x] `DraftService` — 草稿列表加载

### 页面视图 (对齐 fluxdo)

#### 主 Tab — 5 标签 (最新/搜索/分类/书签/我的)
- [x] ContentView — 5 标签布局
- [x] 深色模式支持 — `@AppStorage("appearanceMode")` 控制 `.preferredColorScheme`

#### 首页 — TopicListView
- [x] 筛选 pill bar (最新/热门/精华)
- [x] 下拉刷新 + 无限滚动
- [x] **置顶话题折叠区** — 独立「📌 置顶话题」区域，点击展开/收起
- [x] 普通话题与置顶话题分区显示
- [x] ✏️ 创建话题导航按钮 (NavigationLink → CreateTopicPage)

#### 话题卡片 — TopicRowView
- [x] 左侧头像 40pt
- [x] 状态图标 (lock/accepted-answer/pin)
- [x] fancyTitle → emoji shortcode 自动转换
- [x] 未读蓝色 badge / 回复数
- [x] 标签 pills
- [x] 摘要 (excerpt) → robust HTML stripping
- [x] 底部统计 (❤️ likes 👁 views 💬 replies ⏰ time)

#### 帖子卡片 — PostRowView
- [x] 头像 + 用户名 + 角色徽章 (版主/管理员) + flair 徽章
- [x] 引用回复指示器
- [x] 折叠内容 (hidden/deleted 帖子)
- [x] 操作栏 (点赞/回复/书签/分享)
- [x] 已采纳答案横幅
- [x] "新" 帖子标记
- [x] 图片点击 → ImageViewerPage (onImageTap 回调)

#### 话题详情 — TopicDetailView
- [x] 帖子流列表 + 筛选 (全部/热门/楼主/顶层)
- [x] 回复输入栏
- [x] 书签切换 (跟踪 bookmarkID)
- [x] 分页加载更多
- [x] 图片查看器 fullScreenCover

#### 创建话题 — CreateTopicPage
- [x] 标题输入 + 分类选择器 (Picker) + 标签输入
- [x] Markdown 编辑器 (TextEditor)
- [x] 预览/编辑切换 (ScrollableHTMLPreview)
- [x] 发布 (postForm → posts.json)
- [x] 分类自动加载 (CategoryService)

#### 图片查看器 — ImageViewerPage
- [x] 全屏查看 + 缩放手势 (MagnifyGesture)
- [x] 双击放大/还原
- [x] 下拉关闭手势
- [x] 多图滑动浏览 (TabView)
- [x] 分享按钮 (ShareLink)

#### 通知 — NotificationListView
- [x] 30+ 类型枚举，各类型独立图标+颜色
- [x] 筛选 tabs (全部/未读/提及/回复/赞)
- [x] 已读/未读透明度区分

#### 搜索 — SearchView
- [x] 搜索框 + 错误处理 + 重试按钮
- [x] 帖子结果 → blurb 和 title 经过 `strippingDiscourseMarkup()` 清洗
- [x] 用户结果 → 头像 + 用户名 + 真名
- [x] 话题结果 → 使用 TopicRowView 展示
- [x] **筛选面板** — 分类选择/排序/状态 + 活跃筛选标签

#### 个人中心 — ProfileView (完全对齐 fluxdo)
- [x] 未登录状态 → 登录提示
- [x] 已登录 → 用户头像 + 姓名 + 信任等级徽章
- [x] 统计网格 (访问天数/已读帖子/阅读时间/获赞/帖子/话题)
- [x] 徽章区 + "查看全部"链接
- [x] 菜单：我的话题/我的书签/私信/草稿/浏览历史/我的徽章/信任等级/设置/登出

#### 子页面 (全部在 ProfileView.swift)
- [x] `MyTopicsPage` — 用户话题列表 (UserService.userTopics)
- [x] `PrivateMessagesPage` — 私信列表 (messages.json)
- [x] `PrivateMessageDetailPage` — TopicDetailView 包装器
- [x] `DraftsPage` — 草稿列表 (DraftService)
- [x] `BrowsingHistoryPage` — 浏览历史
- [x] `MyBadgesPage` — 徽章网格列表
- [x] `TrustLevelRequirementsPage` — TL0-TL4 详情
- [x] `SettingsPage` — 进入各设置子页面
- [x] `AppearanceSettingsPage` — 深色模式段选择
- [x] `ReadingSettingsPage` — 字体比例滑块 + 自动加载图片
- [x] `BottomNavSettingsPage` — 占位
- [x] `DataManagementPage` — 缓存大小 + 清除
- [x] `AboutPage` — 应用版本/开发者(qingtengstudio.com)/反馈/开源声明(github.com/Lingyan000/fluxdo)

#### 用户资料 — UserProfilePage
- [x] 他人资料页 — 统计网格 + 话题列表
- [x] 关注按钮 (UserService.toggleFollow)
- [x] FollowListPage — 粉丝/关注列表

#### 书签 — BookmarkListView
- [x] 书签列表 → 点击跳转话题

#### 分类 — CategoryListView
- [x] 分类列表 (颜色点 + 名称 + 描述 + 话题数)
- [x] 点击进入分类话题列表

### HTML 渲染 — DiscourseWebView (WKWebView + CSS 注入)
- [x] WKWebView-based 渲染器，替代 NSAttributedString(html:)
- [x] 深色模式 CSS 注入 — 20+ 变量色值表，自动适配 light/dark
- [x] 字体缩放 — CSS font-size 乘以 @AppStorage("fontSizeScale")
- [x] JS ResizeObserver + scrollHeight 精确高度计算
- [x] 衬线字体 (Times New Roman / Georgia / Noto Serif CJK SC)
- [x] 代码块样式 (等宽字体 + 深色/浅色背景)
- [x] 引用块 (左边框 + 背景色)
- [x] 折叠内容 (details/summary + 箭头指示器)
- [x] Spoiler (点击揭示)
- [x] 表格 (响应式滚动)
- [x] 图片 (max-width:100%, border-radius)
- [x] 链接 (颜色 + 下划线)
- [x] Mention (背景色 + 圆角)
- [x] Onebox (卡片样式)
- [x] Poll (容器样式)
- [x] 图片点击 → ImageViewerPage
- [x] 链接点击 → 内链导航 / 外链 Safari

### 工具
- [x] `TimeUtils` — UTC 时间解析 + 相对时间显示
- [x] `URLHelper` — 头像 URL 拼接
- [x] `DiscourseMarkup` — HTML 标签剥离 + 实体解码 + emoji shortcode 转换

### 关键 Bug 修复
- [x] 所有 Discourse 写操作使用 form-urlencoded (而非 JSON)
- [x] PostService.reply/like/unlike 重写为 form-encoded
- [x] BookmarkService 重写为 form-encoded
- [x] PostActionResponse 编译错误 (重复定义 → 合并到 PaginatedResponse)
- [x] TopicDetail.bookmarked/bookmarkableID 字段 — 书签状态跟踪
- [x] PostStream/posts 改为 var — 支持可变分页合并
- [x] CSRF token 获取使用 HTTPClient.session（共享 Cookie，避免 token 不匹配）
- [x] BAD CSRF 重试策略：所有方法安全重试（BAD CSRF = 请求未被执行）
- [x] `deleteVoid()`/`putVoid()` 改走 `perform()` 获得 CSRF 重试
- [x] 移除手动 `Host` 头 + 添加 `Sec-Fetch-*` 头（防 Cloudflare 拦截）
- [x] 书签删除：`bookmarkID` 为 nil 时从书签列表回退查找
- [x] 书签添加：400 "已收藏" 错误优雅处理（`fetchExistingBookmark`）

---

## 待完成 (对齐 fluxdo 40+ 页面)

### 话题相关
| fluxdo 页面 | 状态 | 说明 |
|------------|------|------|
| `topic_detail_page.dart` | 🔨 需完善 | 缺底部回复栏、AI对话、嵌套回复 |
| `edit_topic_page.dart` | ❌ 未开始 | 编辑话题 |
| `tag_topics_page.dart` | ⚠️ 部分 | 支持按 tag 加载，无独立 UI 入口 |

### 用户/个人
| fluxdo 页面 | 状态 | 说明 |
|------------|------|------|
| `profile_stats_edit_page.dart` | ❌ 未开始 | 编辑个人统计 |

### 核心组件 (Widgets) — 需移植
| fluxdo 组件 | 状态 | 说明 |
|------------|------|------|
| `discourse_html_content/` | ⚠️ 已升级 | UIViewRepresentable，缺 Onebox/投票/自定义 emoji |
| `markdown_editor/` | ⚠️ 基础完成 | CreateTopicPage 有基本编辑器，缺 emoji/贴纸/链接/图片/模板 |
| `nested/` 嵌套回复 | ❌ 未开始 | 嵌套帖子线程 |
| `share/` 分享导出 | ❌ 未开始 | 分享图片/导出 |

### 实时更新
| fluxdo 功能 | 状态 | 说明 |
|------------|------|------|
| MessageBus/WebSocket 实时推送 | ✅ 已完成 | MessageBusService + TopicDetailViewModel 订阅 |

### HTML 渲染升级 (WKWebView + CSS 注入)
- [x] 代码块语法高亮 (CSS)
- [x] 引用块样式 (CSS)
- [x] Onebox 嵌入 (CSS 卡片样式)
- [x] 折叠内容 (spoiler/callout CSS + JS)
- [x] 表格渲染 (CSS 响应式)
- [x] 投票 (poll CSS 容器)
- [x] 图片灯箱 (JS click handler → ImageViewerPage)
- [x] 自定义 emoji (CSS img.emoji 样式)
- [x] Mention (CSS 背景色 + 圆角)

### 质量保障
- [x] 内存泄漏审计 (弱引用 + Task 取消 + deinit 清理)
- [x] 深色模式完整适配 (CSS 注入 + @AppStorage)
- [x] 本地化 (zh-Hans.lproj/Localizable.strings — 186 条)
- [ ] 完整端到端测试

---

## 技术栈

| 项目 | 选择 |
|------|------|
| 语言 | Swift 6 (strict concurrency) |
| UI 框架 | SwiftUI |
| 最低部署 | iOS 17.6 |
| 架构 | MVVM + @Observable |
| 网络 | URLSession (原生) |
| 认证 | WKWebView Cookie Bridge |
| 第三方依赖 | 零 |
| 字体 | 系统衬线体 (Font.Design.serif) |

## 关键模式

| 模式 | 说明 |
|------|------|
| Discourse 写操作 | `HTTPClient.shared.postForm()` / `putForm()` — 必须使用 `application/x-www-form-urlencoded` |
| CSRF 重试 | BAD CSRF = 请求未执行，所有方法安全重试；真实 401 才登出 |
| CSRF 获取 | `CSRFManager.fetchFromServer()` 使用 `HTTPClient.shared.session`（共享 Cookie） |
| 书签删除 | `toggleBookmark()` 先检查 `bookmarkID`，为 nil 时调用 `findBookmarkID()` 回退查找 |
| 书签添加 | 400 "已收藏" → `fetchExistingBookmark()` 返回已有书签（软成功） |
| 不可变编码 | `PostActionResponse` 所有字段 Optional，Discourse 响应不全时可容错 |
| 用户名获取 | `SessionStore.shared.username`，不用 `currentUser?.username` |
| 深色模式 | `@AppStorage("appearanceMode")` → 0=系统、1=浅色、2=深色 |

## 参考

- **fluxdo 源码**: `/fluxdo-main/lib/` — Flutter 原版，所有 UI/功能移植参照
- **Discourse API**: https://docs.discourse.org/
