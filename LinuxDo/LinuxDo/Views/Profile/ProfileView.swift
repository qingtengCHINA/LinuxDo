//
//  ProfileView.swift
//  LinuxDo
//
//  个人中心 — 对照 fluxdo profile_page
//

import SwiftUI

struct ProfileView: View {
    @Environment(AuthViewModel.self) var authVM
    @State private var showLogin = false
    @State private var userSummary: UserSummary?
    @State private var userBadges: [UserBadge] = []
    @State private var isLoadingSummary = false

    var body: some View {
        NavigationStack {
            Group {
                if let user = authVM.currentUser { profileContent(user) }
                else { loginPrompt }
            }
            .navigationTitle("我的")
            .sheet(isPresented: $showLogin) {
                LoginView { Task { await authVM.fetchCurrentUser() } }
            }
            .task {
                if SessionStore.shared.isLoggedIn && authVM.currentUser == nil {
                    await authVM.fetchCurrentUser()
                }
            }
            .onChange(of: authVM.currentUser?.id) { _, _ in loadSummary() }
        }
    }

    private var loginPrompt: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.crop.circle").font(.system(size: 64)).foregroundStyle(.secondary)
            Text("登录 LinuxDo").font(DesignTypography.serifTitle2).fontWeight(.semibold)
            Text("登录后可查看通知、回复话题、管理个人资料")
                .font(DesignTypography.serifSubheadline).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 40)
            Button { showLogin = true } label: {
                Label("登录", systemImage: "arrow.right.circle.fill").font(.headline)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
        }
    }

    @ViewBuilder
    private func profileContent(_ user: User) -> some View {
        List {
            // Avatar + Name + Trust Level
            Section {
                HStack(spacing: 16) {
                    AvatarView(url: user.avatarURL, size: 64)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.name ?? user.username).font(DesignTypography.serifTitle3).fontWeight(.bold)
                        Text("@\(user.username)").font(DesignTypography.serifCaption).foregroundStyle(.secondary)
                        trustLevelBadge(user.trustLevel)
                    }
                }
                .padding(.vertical, 4)
            }

            // Stats
            Section {
                if let summary = userSummary {
                    statsGrid(summary)
                } else if isLoadingSummary {
                    ProgressView().frame(maxWidth: .infinity)
                }
            } header: { Text("统计数据") }

            // Badges (preview)
            Section {
                if userBadges.isEmpty {
                    Text("暂无徽章").font(DesignTypography.serifCaption).foregroundStyle(.secondary)
                } else {
                    ForEach(userBadges.prefix(3)) { ub in
                        HStack(spacing: 10) {
                            if let badge = ub.badge { badgeIcon(badge) }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ub.badge?.name ?? "徽章").font(DesignTypography.serifSubheadline)
                                if ub.count > 1 {
                                    Text("获得 \(ub.count) 次").font(DesignTypography.serifCaption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    NavigationLink {
                        MyBadgesPage(badges: userBadges)
                    } label: {
                        Text("查看全部徽章").font(DesignTypography.serifCaption).foregroundStyle(Color.accentColor)
                    }
                }
            } header: { Text("徽章") }

            // Content — 对照 fluxdo profile_page actions
            Section {
                NavigationLink { MyTopicsPage() } label: {
                    menuRow(icon: "article", iconColor: .blue, title: "我的话题")
                }
                NavigationLink { BookmarkListView() } label: {
                    menuRow(icon: "bookmark.fill", iconColor: .orange, title: "我的书签")
                }
                NavigationLink { PrivateMessagesPage() } label: {
                    menuRow(icon: "envelope.fill", iconColor: .teal, title: "私信")
                }
                NavigationLink { DraftsPage() } label: {
                    menuRow(icon: "doc.text.fill", iconColor: .purple, title: "我的草稿")
                }
                NavigationLink { BrowsingHistoryPage() } label: {
                    menuRow(icon: "clock.arrow.circlepath", iconColor: .green, title: "浏览历史")
                }
                NavigationLink { MyBadgesPage(badges: userBadges) } label: {
                    menuRow(icon: "rosette", iconColor: .yellow, title: "我的徽章")
                }
                NavigationLink { TrustLevelRequirementsPage() } label: {
                    menuRow(icon: "shield.checkered", iconColor: .indigo, title: "信任等级")
                }
            }

            // Settings — 对照 fluxdo settings
            Section {
                NavigationLink { SettingsPage() } label: {
                    menuRow(icon: "gearshape.fill", iconColor: .gray, title: "应用设置")
                }
            }

            // Logout
            Section {
                Button(role: .destructive) { authVM.logout() } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("退出登录")
                    }
                    .foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: - Stats Grid

    private func statsGrid(_ summary: UserSummary) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCard("访问天数", "\(summary.daysVisited)", icon: "calendar")
            statCard("阅读帖子", "\(summary.postsReadCount)", icon: "book")
            statCard("阅读时间", summary.formattedTimeRead, icon: "clock")
            statCard("获赞", "\(summary.likesReceived)", icon: "heart.fill")
            statCard("发帖", "\(summary.postCount)", icon: "text.bubble")
            statCard("话题", "\(summary.topicCount)", icon: "list.bullet")
        }
    }

    private func statCard(_ label: String, _ value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.title3).foregroundStyle(Color.accentColor)
            Text(value).font(DesignTypography.serifTitle3).fontWeight(.semibold)
            Text(label).font(DesignTypography.serifCaption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.tertiarySystemFill)))
    }

    // MARK: - Menu Row

    private func menuRow(icon: String, iconColor: Color, title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(iconColor)
                .frame(width: 28, height: 28)
                .background(iconColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            Text(title).font(DesignTypography.serifBody)
        }
    }

    // MARK: - Badges

    private func badgeIcon(_ badge: Badge) -> some View {
        Group {
            if let imageURL = badge.imageURL, !imageURL.isEmpty {
                AsyncImage(url: URL(string: imageURL)) { img in
                    img.resizable().aspectRatio(contentMode: .fit)
                } placeholder: {
                    Image(systemName: "rosette").foregroundStyle(badgeColor(badge.badgeType))
                }
                .frame(width: 28, height: 28)
            } else {
                Image(systemName: "rosette").font(.title3).foregroundStyle(badgeColor(badge.badgeType))
            }
        }
    }

    private func badgeColor(_ type: BadgeType) -> Color {
        switch type {
        case .gold: return .yellow
        case .silver: return .gray
        case .bronze: return .orange
        }
    }

    private func trustLevelBadge(_ level: Int) -> some View {
        let text: String = switch level {
        case 0: "访客"
        case 1: "成员"
        case 2: "活跃成员"
        case 3: "资深成员"
        case 4: "领袖"
        default: "TL\(level)"
        }
        let color: Color = switch level {
        case 4: .purple
        case 3: .blue
        case 2: .green
        default: .secondary
        }
        return Text(text).font(DesignTypography.serifCaption2).fontWeight(.medium)
            .padding(.horizontal, 8).padding(.vertical, 2)
            .background(color.opacity(0.12)).foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Data Loading

    private func loadSummary() {
        guard let user = authVM.currentUser, userSummary == nil else { return }
        Task {
            isLoadingSummary = true
            defer { isLoadingSummary = false }
            do { userSummary = try await UserService.shared.summary(username: user.username) } catch { }
            do { let resp = try await UserService.shared.badges(username: user.username); userBadges = resp.userBadges } catch { }
        }
    }
}

// MARK: - My Topics Page

struct MyTopicsPage: View {
    @State private var viewModel = TopicListViewModel()

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.topics) { t in
                    NavigationLink {
                        TopicDetailView(topicID: t.id, topicTitle: t.title)
                    } label: { TopicRowView(topic: t) }.buttonStyle(.plain)
                }
                if viewModel.topics.isEmpty && !viewModel.isLoadingMore {
                    ContentUnavailableView("暂无话题", systemImage: "doc.text")
                }
                if viewModel.isLoadingMore { ProgressView().padding() }
            }
        }
        .navigationTitle("我的话题")
        .refreshable { await viewModel.refresh() }
        .task { await viewModel.loadMyTopics() }
    }
}

// MARK: - Private Messages Page

struct PrivateMessagesPage: View {
    @State private var topics: [Topic] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading { ProgressView() }
            else if topics.isEmpty {
                ContentUnavailableView("暂无私信", systemImage: "envelope")
            } else {
                List(topics) { topic in
                    NavigationLink {
                        PrivateMessageDetailPage(topicID: topic.id, topicTitle: topic.title)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(topic.title.strippingDiscourseMarkup()).font(DesignTypography.serifBody).lineLimit(2)
                            Text(TimeUtils.relative(from: topic.bumpedAt)).font(DesignTypography.serifCaption2).foregroundStyle(.secondary)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("私信")
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        do {
            let resp: TopicListResponse = try await HTTPClient.shared.get("messages.json")
            topics = resp.topicList.topics
        } catch { }
        isLoading = false
    }
}

// MARK: - Drafts Page

struct DraftsPage: View {
    @State private var drafts: [Draft] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading { ProgressView() }
            else if drafts.isEmpty {
                ContentUnavailableView("暂无草稿", systemImage: "doc.text")
            } else {
                List(drafts) { draft in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(draft.title ?? "无标题").font(DesignTypography.serifBody).lineLimit(1)
                        if let excerpt = draft.excerpt {
                            Text(excerpt).font(DesignTypography.serifCaption).foregroundStyle(.secondary).lineLimit(2)
                        }
                        Text(TimeUtils.relative(from: draft.createdAt)).font(DesignTypography.serifCaption2).foregroundStyle(.tertiary)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("我的草稿")
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        do { drafts = try await DraftService.list() } catch { }
        isLoading = false
    }
}

// MARK: - Browsing History Page

struct BrowsingHistoryPage: View {
    @State private var topics: [Topic] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading { ProgressView() }
            else if topics.isEmpty {
                ContentUnavailableView("暂无浏览历史", systemImage: "clock.arrow.circlepath")
            } else {
                List(topics) { topic in
                    NavigationLink {
                        TopicDetailView(topicID: topic.id, topicTitle: topic.title)
                    } label: {
                        TopicRowView(topic: topic)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("浏览历史")
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        do {
            let resp: TopicListResponse = try await HTTPClient.shared.get("topics/created-by/\(SessionStore.shared.username ?? "").json")
            topics = resp.topicList.topics
        } catch { }
        isLoading = false
    }
}

// MARK: - My Badges Page

struct MyBadgesPage: View {
    let badges: [UserBadge]
    @State private var allBadges: [UserBadge] = []

    init(badges: [UserBadge]) {
        self.badges = badges
        self._allBadges = State(initialValue: badges)
    }

    var body: some View {
        List(allBadges) { ub in
            HStack(spacing: 12) {
                if let badge = ub.badge {
                    BadgeRowIcon(badge: badge)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(ub.badge?.name ?? "徽章").font(DesignTypography.serifBody)
                    if ub.count > 1 {
                        Text("获得 \(ub.count) 次").font(DesignTypography.serifCaption).foregroundStyle(.secondary)
                    }
                    if let granted = ub.grantedAt {
                        Text(TimeUtils.relative(from: granted)).font(DesignTypography.serifCaption2).foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .navigationTitle("我的徽章")
        .listStyle(.plain)
    }
}

private struct BadgeRowIcon: View {
    let badge: Badge
    var body: some View {
        if let imageURL = badge.imageURL, !imageURL.isEmpty {
            AsyncImage(url: URL(string: imageURL)) { img in
                img.resizable().aspectRatio(contentMode: .fit)
            } placeholder: {
                Image(systemName: "rosette").foregroundStyle(badgeColor)
            }
            .frame(width: 32, height: 32)
        } else {
            Image(systemName: "rosette").font(.title2).foregroundStyle(badgeColor)
        }
    }

    private var badgeColor: Color {
        switch badge.badgeType {
        case .gold: return .yellow
        case .silver: return .gray
        case .bronze: return .orange
        }
    }
}

// MARK: - Trust Level Requirements Page

struct TrustLevelRequirementsPage: View {
    private let levels: [(String, String, [(String, String)])] = [
        ("TL1 — 成员", "基础权限", [
            ("进入话题", "浏览话题的最低要求"),
            ("基本操作", "点赞、书签、标记"),
        ]),
        ("TL2 — 活跃成员", "需要更多互动", [
            ("访问天数", "≥ 15 天"),
            ("话题阅读", "浏览 ≥ 20 个话题"),
            ("阅读帖子", "阅读 ≥ 100 个帖子"),
            ("阅读时间", "≥ 60 分钟"),
        ]),
        ("TL3 — 资深成员", "社区核心用户", [
            ("访问天数", "最近 100 天内 ≥ 50 天"),
            ("阅读帖子", "≥ 20,000 帖子"),
            ("阅读话题", "近期浏览过 ≥ 数十个话题"),
        ]),
        ("TL4 — 领袖", "社区支柱", [
            ("需要 TL3", "已是资深成员"),
            ("社区贡献", "大量高质量内容"),
            ("由管理员手动授予", "非自动升级"),
        ]),
    ]

    var body: some View {
        List {
            ForEach(levels, id: \.0) { level in
                Section {
                    ForEach(level.2, id: \.0) { req in
                        HStack {
                            Text(req.0).font(DesignTypography.serifBody)
                            Spacer()
                            Text(req.1).font(DesignTypography.serifCaption).foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(level.0).font(DesignTypography.serifHeadline)
                        Text(level.1).font(DesignTypography.serifCaption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("信任等级")
        .listStyle(.insetGrouped)
    }
}

// MARK: - Settings Page

struct SettingsPage: View {
    var body: some View {
        List {
            Section {
                NavigationLink { AppearanceSettingsPage() } label: {
                    settingsRow(icon: "paintbrush.fill", iconColor: .purple, title: "外观设置", subtitle: "深色/浅色/跟随系统")
                }
                NavigationLink { ReadingSettingsPage() } label: {
                    settingsRow(icon: "book.fill", iconColor: .orange, title: "阅读设置", subtitle: "字体大小、图片加载")
                }
            }

            Section {
                NavigationLink { BottomNavSettingsPage() } label: {
                    settingsRow(icon: "list.bullet", iconColor: .blue, title: "底栏设置", subtitle: "自定义底部导航")
                }
                NavigationLink { DataManagementPage() } label: {
                    settingsRow(icon: "externaldrive.fill", iconColor: .gray, title: "数据管理", subtitle: "缓存、存储")
                }
            }

            Section {
                NavigationLink { AboutPage() } label: {
                    settingsRow(icon: "info.circle.fill", iconColor: .blue, title: "关于")
                }
            }
        }
        .navigationTitle("设置")
        .listStyle(.insetGrouped)
    }

    private func settingsRow(icon: String, iconColor: Color, title: String, subtitle: String? = nil) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.body).foregroundStyle(iconColor)
                .frame(width: 28, height: 28).background(iconColor.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(DesignTypography.serifBody)
                if let sub = subtitle { Text(sub).font(DesignTypography.serifCaption2).foregroundStyle(.secondary) }
            }
        }
    }
}

// MARK: - Appearance Settings

struct AppearanceSettingsPage: View {
    @AppStorage("appearanceMode") private var appearanceMode = 0 // 0=system, 1=light, 2=dark

    var body: some View {
        List {
            Section {
                Picker("主题模式", selection: $appearanceMode) {
                    Text("跟随系统").tag(0)
                    Text("浅色模式").tag(1)
                    Text("深色模式").tag(2)
                }
                .pickerStyle(.segmented)
            } header: { Text("外观") }
        }
        .navigationTitle("外观设置")
        .listStyle(.insetGrouped)
    }
}

// MARK: - Reading Settings

struct ReadingSettingsPage: View {
    @AppStorage("fontSizeScale") private var fontSizeScale = 1.0
    @AppStorage("autoLoadImages") private var autoLoadImages = true

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading) {
                    Text("字体大小倍率").font(DesignTypography.serifBody)
                    HStack {
                        Text("A").font(.caption)
                        Slider(value: $fontSizeScale, in: 0.8...1.5, step: 0.1)
                        Text("A").font(.title3)
                    }
                    Text(String(format: "%.1fx", fontSizeScale)).font(DesignTypography.serifCaption).foregroundStyle(.secondary)
                }
            } header: { Text("阅读") }

            Section {
                Toggle("自动加载图片", isOn: $autoLoadImages)
            } header: { Text("数据") }
        }
        .navigationTitle("阅读设置")
        .listStyle(.insetGrouped)
    }
}

// MARK: - Bottom Nav Settings

struct BottomNavSettingsPage: View {
    var body: some View {
        List {
            Section {
                Text("当前底部导航栏：最新、搜索、分类、书签、我的")
                    .font(DesignTypography.serifBody)
            } header: { Text("导航栏") }

            Section {
                Text("自定义底部导航栏功能开发中…")
                    .font(DesignTypography.serifCaption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("底栏设置")
        .listStyle(.insetGrouped)
    }
}

// MARK: - Data Management

struct DataManagementPage: View {
    @State private var cacheSize = "计算中..."

    var body: some View {
        List {
            Section {
                HStack {
                    Text("磁盘缓存").font(DesignTypography.serifBody)
                    Spacer()
                    Text(cacheSize).font(DesignTypography.serifCaption).foregroundStyle(.secondary)
                }
                Button("清除缓存") { clearCache() }
                    .foregroundStyle(.red)
            } header: { Text("存储") }
        }
        .navigationTitle("数据管理")
        .listStyle(.insetGrouped)
        .task { calculateCacheSize() }
    }

    private func calculateCacheSize() {
        let cacheDir = URL.cachesDirectory
        var total: Int64 = 0
        if let files = try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.fileSizeKey]) {
            for file in files {
                if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize { total += Int64(size) }
            }
        }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        cacheSize = formatter.string(fromByteCount: total)
    }

    private func clearCache() {
        try? FileManager.default.removeItem(at: URL.cachesDirectory)
        cacheSize = "0 KB"
    }
}

// MARK: - About Page

struct AboutPage: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Image("LinuxDo 1").resizable().scaledToFit().frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 14))
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("LinuxDo").font(DesignTypography.serifTitle2).fontWeight(.bold)
                    Text("版本 \(appVersion) (\(buildNumber))").font(DesignTypography.serifCaption).foregroundStyle(.secondary)
                }
            }

            Section {
                LinkRow(title: "开发者", subtitle: "qingtengstudio.com", url: URL(string: "https://qingtengstudio.com/")!)
                LinkRow(title: "反馈问题", subtitle: "提交 Bug 或建议", url: URL(string: "https://qingtengstudio.com/")!)
                LinkRow(title: "开源声明", subtitle: "基于 fluxdo 开源项目", url: URL(string: "https://github.com/Lingyan000/fluxdo")!)
            } header: { Text("关于") }

            Section {
                Text("基于 GPL-3.0 开源协议").font(DesignTypography.serifCaption).foregroundStyle(.secondary)
                Text("感谢 Linux.do 社区").font(DesignTypography.serifCaption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("关于")
        .listStyle(.insetGrouped)
    }
}

private struct LinkRow: View {
    let title: String
    let subtitle: String
    let url: URL

    var body: some View {
        Link(destination: url) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(DesignTypography.serifBody)
                    Text(subtitle).font(DesignTypography.serifCaption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - BookmarkListView

struct BookmarkListView: View {
    @State private var topics: [Topic] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            List {
            ForEach(topics) { t in
                NavigationLink {
                    TopicDetailView(
                        topicID: t.id,
                        topicTitle: t.title
                    )
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        bookmarkMetaBar(t)
                        Text((t.fancyTitle ?? t.title).strippingDiscourseMarkup())
                            .font(DesignTypography.serifSubheadline).fontWeight(.medium)
                        if let excerpt = t.excerpt?.strippingDiscourseMarkup(), !excerpt.isEmpty {
                            Text(excerpt).font(DesignTypography.serifCaption).foregroundStyle(.secondary).lineLimit(2)
                        }
                        HStack(spacing: 12) {
                            if t.views > 0 { Label("\(t.views)", systemImage: "eye").font(DesignTypography.serifCaption2).foregroundStyle(.tertiary) }
                            if t.replyCount > 0 { Label("\(t.replyCount)", systemImage: "bubble.left").font(DesignTypography.serifCaption2).foregroundStyle(.tertiary) }
                            if t.likeCount > 0 { Label("\(t.likeCount)", systemImage: "heart").font(DesignTypography.serifCaption2).foregroundStyle(.tertiary) }
                            Spacer()
                            if let date = t.lastPostedAt ?? t.bumpedAt { Text(TimeUtils.relative(from: date)).font(DesignTypography.serifCaption2).foregroundStyle(.tertiary) }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("书签")
        .overlay { if topics.isEmpty && !isLoading { ContentUnavailableView("暂无书签", systemImage: "bookmark") } }
        .task { await loadBookmarks() }
        .refreshable { await loadBookmarks() }
        }
    }

    @ViewBuilder
    private func bookmarkMetaBar(_ t: Topic) -> some View {
        let hasName = t.bookmarkName != nil && !t.bookmarkName!.isEmpty
        let hasReminder = t.bookmarkReminderAt != nil
        if hasName || hasReminder {
            HStack(spacing: 4) {
                if hasName {
                    Image(systemName: "bookmark.fill").font(.caption2).foregroundStyle(.tint)
                    Text(t.bookmarkName!).font(.caption2).foregroundStyle(.secondary)
                }
                if hasReminder {
                    if hasName { Text("·").font(.caption2).foregroundStyle(.tertiary) }
                    Image(systemName: "alarm").font(.caption2).foregroundStyle(.tint)
                    let isExpired = t.bookmarkReminderAt!.timeIntervalSinceNow < 0
                    Text(isExpired ? "已过期" : TimeUtils.relative(from: t.bookmarkReminderAt!))
                        .font(.caption2).foregroundStyle(isExpired ? .red : .secondary)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func loadBookmarks() async {
        isLoading = true
        defer { isLoading = false }
        do {
            topics = try await BookmarkService.shared.bookmarks()
        } catch {
            print("❌ BookmarkListView: \(error)")
        }
    }
}

// MARK: - SearchView (now in tab bar, with filters)

struct SearchView: View {
    @State private var query = ""
    @State private var results: SearchResult?
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var showFilterSheet = false
    @State private var selectedCategoryID: Int?
    @State private var selectedOrder: SearchOrder = .latest
    @State private var selectedStatus: SearchStatus?
    @State private var categories: [DiscourseCategory] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField
                filterChips
                searchContent
            }
            .navigationTitle("搜索")
            .sheet(isPresented: $showFilterSheet) { filterSheet }
            .task { await loadCategories() }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            TextField("搜索话题、帖子、用户...", text: $query)
                .font(DesignTypography.serifBody)
                .textFieldStyle(.roundedBorder)
                .onSubmit { performSearch() }
            if isSearching {
                ProgressView().frame(width: 20, height: 20)
            } else {
                Button("搜索") { performSearch() }
                    .font(DesignTypography.serifSubheadline).buttonStyle(.bordered)
            }
            Button { showFilterSheet = true } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(hasActiveFilters ? Color.accentColor : .secondary)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }

    private var hasActiveFilters: Bool {
        selectedCategoryID != nil || selectedOrder != .latest || selectedStatus != nil
    }

    @ViewBuilder
    private var filterChips: some View {
        if hasActiveFilters {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if let catID = selectedCategoryID, let cat = categories.first(where: { $0.id == catID }) {
                        FilterChip(text: cat.name) { selectedCategoryID = nil; performSearch() }
                    }
                    if selectedOrder != .latest {
                        FilterChip(text: selectedOrder.displayName) { selectedOrder = .latest; performSearch() }
                    }
                    if let status = selectedStatus {
                        FilterChip(text: status.displayName) { selectedStatus = nil; performSearch() }
                    }
                }
                .padding(.horizontal, 12)
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var searchContent: some View {
        if let err = errorMessage {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundStyle(.secondary)
                Text(err).font(DesignTypography.serifCaption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button("重试") { performSearch() }.buttonStyle(.bordered)
            }
            .padding()
            Spacer()
        } else if let r = results {
            if r.isEmpty {
                ContentUnavailableView("无搜索结果", systemImage: "magnifyingglass")
            } else {
                List {
                    if let posts = r.posts, !posts.isEmpty {
                        Section("帖子") {
                            ForEach(posts) { p in
                                NavigationLink {
                                    TopicDetailView(topicID: p.topicID ?? 0, topicTitle: p.displayTitle)
                                } label: {
                                    VStack(alignment: .leading, spacing: 3) {
                                        if !p.displayTitle.isEmpty { Text(p.displayTitle).font(DesignTypography.serifSubheadline).lineLimit(1) }
                                        Text(p.displayBlurb).font(DesignTypography.serifCaption).foregroundStyle(.secondary).lineLimit(2)
                                        Text("@\(p.username)").font(DesignTypography.serifCaption2).foregroundStyle(.tertiary)
                                    }
                                }
                            }
                        }
                    }
                    if let users = r.users, !users.isEmpty {
                        Section("用户") {
                            ForEach(users) { u in
                                NavigationLink {
                                    UserProfilePage(username: u.username)
                                } label: {
                                    HStack(spacing: 10) {
                                        AvatarView(url: u.avatarURL, size: 32)
                                        VStack(alignment: .leading) {
                                            Text(u.username).font(DesignTypography.serifSubheadline)
                                            if let n = u.name { Text(n).font(DesignTypography.serifCaption).foregroundStyle(.secondary) }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    if let topics = r.topics, !topics.isEmpty {
                        Section("话题") {
                            ForEach(topics) { t in
                                NavigationLink {
                                    TopicDetailView(topicID: t.id, topicTitle: t.title)
                                } label: {
                                    Text(t.title.strippingDiscourseMarkup()).font(DesignTypography.serifSubheadline)
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        } else {
            ContentUnavailableView("输入关键词搜索", systemImage: "magnifyingglass")
        }
    }

    // MARK: - Filter Sheet

    private var filterSheet: some View {
        NavigationStack {
            List {
                Section {
                    Picker("排序", selection: $selectedOrder) {
                        ForEach(SearchOrder.allCases, id: \.self) { order in
                            Text(order.displayName).tag(order)
                        }
                    }
                }

                Section {
                    Picker("分类", selection: $selectedCategoryID) {
                        Text("全部").tag(Int?.none)
                        ForEach(categories) { cat in
                            Text(cat.name).tag(Int?(cat.id))
                        }
                    }
                }

                Section {
                    Picker("状态", selection: $selectedStatus) {
                        Text("全部").tag(SearchStatus?.none)
                        ForEach(SearchStatus.allCases, id: \.self) { status in
                            Text(status.displayName).tag(SearchStatus?(status))
                        }
                    }
                }

                Section {
                    Button("重置筛选") {
                        selectedCategoryID = nil
                        selectedOrder = .latest
                        selectedStatus = nil
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("搜索筛选")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { showFilterSheet = false; performSearch() }
                }
            }
        }
    }

    private func performSearch() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        Task {
            isSearching = true
            errorMessage = nil
            do {
                results = try await SearchService.shared.search(
                    query: q,
                    categoryID: selectedCategoryID,
                    order: selectedOrder,
                    status: selectedStatus
                )
            } catch {
                errorMessage = error.localizedDescription
            }
            isSearching = false
        }
    }

    private func loadCategories() async {
        guard categories.isEmpty else { return }
        do { categories = try await CategoryService.list().categoryList.categories } catch { }
    }
}

private struct FilterChip: View {
    let text: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(text).font(DesignTypography.serifCaption2)
            Button(action: onRemove) { Image(systemName: "xmark.circle.fill").font(.system(size: 14)) }
        }
        .padding(.horizontal, 10).padding(.vertical, 4)
        .background(Capsule().fill(Color.accentColor.opacity(0.12)))
        .foregroundStyle(Color.accentColor)
        .clipShape(Capsule())
    }
}

// MARK: - User Profile Page (viewing other users)

struct UserProfilePage: View {
    let username: String
    @State private var user: User?
    @State private var summary: UserSummary?
    @State private var userTopics: [Topic] = []
    @State private var isLoading = true
    @State private var isFollowing = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if isLoading {
                    ProgressView().padding(.top, 40)
                } else if let user {
                    userProfileContent(user)
                } else {
                    ContentUnavailableView("无法加载用户信息", systemImage: "person.crop.circle.badge.exclamationmark")
                }
            }
            .padding()
        }
        .navigationTitle("@\(username)")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    @ViewBuilder
    private func userProfileContent(_ user: User) -> some View {
        VStack(spacing: 8) {
            AvatarView(url: user.avatarURL, size: 80)
            Text(user.name ?? user.username).font(DesignTypography.serifTitle2).fontWeight(.bold)
            Text("@\(user.username)").font(DesignTypography.serifCaption).foregroundStyle(.secondary)
            if user.trustLevel > 0 {
                trustLevelBadge(user.trustLevel)
            }
        }
        .padding(.top, 8)

        Button {
            Task { await toggleFollow() }
        } label: {
            Text(isFollowing ? "已关注" : "关注")
                .font(DesignTypography.serifSubheadline).fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isFollowing ? Color.secondary.opacity(0.12) : Color.accentColor)
                .foregroundStyle(isFollowing ? Color.primary : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.horizontal)

        if let summary {
            statsGrid(summary)
        }

        if !userTopics.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("最近话题").font(DesignTypography.serifHeadline).padding(.horizontal)
                ForEach(userTopics.prefix(5)) { topic in
                    NavigationLink {
                        TopicDetailView(topicID: topic.id, topicTitle: topic.title)
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(topic.title.strippingDiscourseMarkup()).font(DesignTypography.serifSubheadline).lineLimit(2)
                                HStack(spacing: 8) {
                                    Label("\(topic.replyCount)", systemImage: "text.bubble").font(DesignTypography.serifCaption2)
                                    Label("\(topic.views)", systemImage: "eye").font(DesignTypography.serifCaption2)
                                }.foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }

    private func statsGrid(_ summary: UserSummary) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCard("访问天数", "\(summary.daysVisited)", icon: "calendar")
            statCard("阅读帖子", "\(summary.postsReadCount)", icon: "book")
            statCard("阅读时间", summary.formattedTimeRead, icon: "clock")
            statCard("获赞", "\(summary.likesReceived)", icon: "heart.fill")
        }
        .padding(.horizontal)
    }

    private func statCard(_ label: String, _ value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.title3).foregroundStyle(Color.accentColor)
            Text(value).font(DesignTypography.serifTitle3).fontWeight(.semibold)
            Text(label).font(DesignTypography.serifCaption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.tertiarySystemFill)))
    }

    private func trustLevelBadge(_ level: Int) -> some View {
        let text: String = switch level {
        case 0: "访客"
        case 1: "成员"
        case 2: "活跃成员"
        case 3: "资深成员"
        case 4: "领袖"
        default: "TL\(level)"
        }
        let color: Color = switch level {
        case 4: .purple
        case 3: .blue
        case 2: .green
        default: .secondary
        }
        return Text(text).font(DesignTypography.serifCaption2).fontWeight(.medium)
            .padding(.horizontal, 8).padding(.vertical, 2)
            .background(color.opacity(0.12)).foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func load() async {
        isLoading = true
        do {
            user = try await UserService.shared.profile(username: username)
            if let user {
                async let summaryTask = UserService.shared.summary(username: username)
                async let topicsTask = UserService.shared.userTopics(username: username)
                summary = try? await summaryTask
                let resp = try? await topicsTask
                userTopics = resp?.topicList.topics ?? []
            }
        } catch { }
        isLoading = false
    }

    private func toggleFollow() async {
        guard user != nil else { return }
        do {
            try await UserService.shared.toggleFollow(username: username, isFollowing: isFollowing)
            isFollowing.toggle()
        } catch { }
    }
}

// MARK: - Follow List Page

struct FollowListPage: View {
    let username: String
    let isFollowers: Bool
    @State private var users: [SearchUser] = []
    @State private var isLoading = true

    init(username: String, isFollowers: Bool = true) {
        self.username = username
        self.isFollowers = isFollowers
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if users.isEmpty {
                ContentUnavailableView(isFollowers ? "暂无关注者" : "暂无关注", systemImage: "person.2")
            } else {
                List(users) { user in
                    NavigationLink {
                        UserProfilePage(username: user.username)
                    } label: {
                        HStack(spacing: 12) {
                            AvatarView(url: user.avatarURL, size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.username).font(DesignTypography.serifBody)
                                if let name = user.name { Text(name).font(DesignTypography.serifCaption).foregroundStyle(.secondary) }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(isFollowers ? "关注者" : "关注")
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        let endpoint = isFollowers ? "u/\(username)/followers.json" : "u/\(username)/following.json"
        do {
            struct Response: Decodable { let users: [SearchUser]? }
            let resp: Response = try await HTTPClient.shared.get(endpoint)
            users = resp.users ?? []
        } catch { }
        isLoading = false
    }
}

// MARK: - Private Message Detail Page

struct PrivateMessageDetailPage: View {
    let topicID: Int
    let topicTitle: String

    var body: some View {
        TopicDetailView(topicID: topicID, topicTitle: topicTitle)
    }
}