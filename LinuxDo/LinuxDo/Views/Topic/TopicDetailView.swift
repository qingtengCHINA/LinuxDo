//
//  TopicDetailView.swift
//  LinuxDo
//
//  话题详情 — 帖子流 + 底部操作栏 + 进度条
//  对照 fluxdo topic_detail_page + topic_bottom_bar + topic_detail_overlay
//

import SwiftUI

struct TopicDetailView: View {
    let topicID: Int
    let topicTitle: String

    @State private var viewModel = TopicDetailViewModel()
    @State private var replyText = ""
    @State private var isReplying = false
    @FocusState private var isReplyFocused: Bool
    @State private var showFilterMenu = false
    @State private var filterMode: PostFilterMode = .all
    @State private var showShareMenu = false
    @State private var showMoreMenu = false
    @State private var showImageViewer = false
    @State private var viewerImageURL: String?
    @State private var editPost: PostEditInfo?
    @State private var navigatedTopicID: Int?
    @State private var navigatedTopicTitle: String = ""

    struct PostEditInfo: Identifiable {
        let id: Int
        let postNumber: Int
    }

    enum PostFilterMode: Equatable {
        case all, hotOnly, authorOnly, topLevelOnly
    }

    private var filteredPosts: [Post] {
        switch filterMode {
        case .all: return viewModel.posts
        case .hotOnly: return viewModel.posts.filter { $0.likeCount > 0 || $0.replyCount > 0 }
        case .authorOnly:
            guard let op = viewModel.posts.first?.username else { return viewModel.posts }
            return viewModel.posts.filter { $0.username == op }
        case .topLevelOnly: return viewModel.posts.filter { $0.replyToPostNumber == nil }
        }
    }

    private var progressPercent: Double {
        let total = viewModel.detail?.postStream.stream.count ?? 0
        guard total > 1 else { return 0 }
        let current = viewModel.currentPostIndex
        return Double(current) / Double(total - 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            contentArea
            bottomBar
        }
        .navigationTitle(viewModel.detail?.title.strippingDiscourseMarkup() ?? topicTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .sheet(isPresented: $showFilterMenu) { filterSheet }
        .confirmationDialog("分享", isPresented: $showShareMenu) { shareActions }
        .confirmationDialog("更多操作", isPresented: $showMoreMenu) { moreActions }
        .task { await viewModel.load(topicID: topicID) }
        .fullScreenCover(isPresented: $showImageViewer) {
            if let url = viewerImageURL {
                ImageViewerPage(url: url)
            }
        }
        .sheet(item: $editPost) { info in
            EditPostPage(postID: info.id, postNumber: info.postNumber, topicID: topicID)
        }
        .navigationDestination(item: $navigatedTopicID) { id in
            TopicDetailView(topicID: id, topicTitle: navigatedTopicTitle)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentArea: some View {
        if viewModel.isLoading && viewModel.posts.isEmpty {
            Spacer(); ProgressView(); Spacer()
        } else if let err = viewModel.errorMessage, viewModel.posts.isEmpty {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundStyle(.orange)
                Text(err).font(DesignTypography.serifBody).foregroundStyle(.secondary)
                Button("重试") { Task { await viewModel.load(topicID: topicID) } }.buttonStyle(.bordered)
            }
            Spacer()
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if viewModel.hasLiveUpdates, let text = viewModel.liveUpdateText {
                            liveUpdateBanner(text)
                        }

                        ForEach(Array(filteredPosts.enumerated()), id: \.element.id) { idx, post in
                            PostRowView(
                                post: post,
                                isOriginalPost: idx == 0,
                                onReply: {
                                    replyText = "@\(post.username) "
                                    isReplyFocused = true
                                },
                                onLike: { Task { await viewModel.like(postID: post.id) } },
                                onBookmark: { Task { await viewModel.togglePostBookmark(post: post) } },
                                onShare: {
                                    UIPasteboard.general.string = "https://linux.do/t/\(viewModel.detail?.slug ?? "")/\(topicID)/\(post.postNumber)"
                                },
                                onImageTap: { url in viewerImageURL = url },
                                onEdit: {
                                    editPost = PostEditInfo(id: post.id, postNumber: post.postNumber)
                                },
                                onLinkTap: { url in handleLink(url) }
                            )
                            .id(post.id)
                            .onAppear {
                                viewModel.currentPostIndex = post.postNumber
                                if post.id == filteredPosts.last?.id {
                                    Task { await viewModel.loadMore() }
                                }
                            }

                            Divider()
                        }

                        if viewModel.isLoadingMore {
                            HStack { Spacer(); ProgressView(); Spacer() }.padding()
                        }
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .refreshable { await viewModel.refresh() }
                .onChange(of: viewModel.posts.count) { _, _ in
                    if isReplying, let lastID = viewModel.posts.last?.id {
                        withAnimation { proxy.scrollTo(lastID, anchor: .bottom) }
                    }
                }
            }
        }
    }

    private func liveUpdateBanner(_ text: String) -> some View {
        Button {
            viewModel.clearLiveUpdateNotice()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "dot.radiowaves.left.and.right")
                Text(text)
                Spacer()
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
            }
            .font(DesignTypography.serifCaption)
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.accentColor.opacity(0.1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom Bar (对照 fluxdo TopicBottomBar)

    private var bottomBar: some View {
        VStack(spacing: 0) {
            // Progress bar
            if currentFilterMode() != .all {
                progressBar
            }

            Divider()

            HStack(spacing: 4) {
                // Scroll to top
                bottomButton(icon: "arrow.up.to.line") {
                    withAnimation {
                        if let firstID = filteredPosts.first?.id {
                            ScrollViewReader { _ in } // proxy.scrollTo handled by List
                        }
                    }
                }

                // Filter mode
                if filterMode != .all {
                    Button {
                        filterMode = .all
                    } label: {
                        Image(systemName: filterModeIcon())
                            .font(.system(size: 14))
                            .foregroundStyle(Color.accentColor)
                            .padding(6)
                            .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                    }
                } else {
                    bottomButton(icon: "line.3.horizontal.decrease.circle") {
                        showFilterMenu = true
                    }
                }

                // Share menu
                bottomButton(icon: "square.and.arrow.up") {
                    showShareMenu = true
                }

                // Open in browser
                bottomButton(icon: "globe") {
                    if let slug = viewModel.detail?.slug {
                        UIApplication.shared.open(URL(string: "https://linux.do/t/\(slug)/\(topicID)")!)
                    }
                }

                Spacer()

                // Reply button
                Button {
                    isReplyFocused = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil").font(.system(size: 12))
                        Text("回复").font(DesignTypography.serifCaption).fontWeight(.medium)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Capsule().fill(Color.accentColor))
                    .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 6)

            // Reply input (when focused)
            if isReplyFocused || !replyText.isEmpty {
                replyInputBar
            }
        }
        .background(.regularMaterial)
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color(.tertiarySystemFill)).frame(height: 2)
                Rectangle().fill(Color.accentColor.opacity(0.6))
                    .frame(width: geo.size.width * progressPercent, height: 2)
            }
        }
        .frame(height: 2)
    }

    private var replyInputBar: some View {
        HStack(spacing: 12) {
            TextField("输入回复...", text: $replyText, axis: .vertical)
                .font(DesignTypography.serifBody)
                .focused($isReplyFocused)
                .lineLimit(1...5)
                .padding(.vertical, 8)

            Button {
                let t = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty else { return }
                replyText = ""
                isReplyFocused = false
                isReplying = true
                Task { _ = await viewModel.reply(raw: t); isReplying = false }
            } label: {
                if isReplying {
                    ProgressView()
                } else {
                    Image(systemName: "arrow.up.circle.fill").font(.title2)
                }
            }
            .disabled(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isReplying)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color(.secondarySystemGroupedBackground))
    }

    // MARK: - Filter Sheet

    private var filterSheet: some View {
        NavigationStack {
            List {
                if viewModel.detail?.postStream.posts.filter({ $0.likeCount > 0 || $0.replyCount > 0 }).isEmpty == false {
                    filterRow(icon: "flame.fill", title: "热门回复", mode: .hotOnly)
                }
                filterRow(icon: "person.fill", title: "只看楼主", mode: .authorOnly)
                filterRow(icon: "arrow.triangle.branch", title: "只看直楼", mode: .topLevelOnly)
            }
            .navigationTitle("筛选帖子")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { showFilterMenu = false }
                }
            }
        }
    }

    private func filterRow(icon: String, title: String, mode: PostFilterMode) -> some View {
        Button {
            filterMode = mode
            showFilterMenu = false
        } label: {
            Label(title, systemImage: icon)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button { showFilterMenu = true } label: {
                    Label("筛选", systemImage: "line.3.horizontal.decrease.circle")
                }
                Button { Task { await viewModel.refresh() } } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                if viewModel.isBookmarked {
                    Button { Task { await viewModel.toggleBookmark() } } label: {
                        Label("取消书签", systemImage: "bookmark.fill")
                    }
                } else {
                    Button { Task { await viewModel.toggleBookmark() } } label: {
                        Label("添加书签", systemImage: "bookmark")
                    }
                }
                Button { showMoreMenu = true } label: {
                    Label("更多", systemImage: "ellipsis.circle")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    @ViewBuilder
    private var shareActions: some View {
        Button("复制链接") {
            UIPasteboard.general.string = "https://linux.do/t/\(viewModel.detail?.slug ?? "")/\(topicID)"
        }
        Button("在浏览器中打开") {
            if let slug = viewModel.detail?.slug {
                UIApplication.shared.open(URL(string: "https://linux.do/t/\(slug)/\(topicID)")!)
            }
        }
    }

    @ViewBuilder
    private var moreActions: some View {
        Button("在浏览器中打开") {
            if let slug = viewModel.detail?.slug {
                UIApplication.shared.open(URL(string: "https://linux.do/t/\(slug)/\(topicID)")!)
            }
        }
    }

    // MARK: - Helpers

    private func bottomButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 36, height: 36)
        }
    }

    private func currentFilterMode() -> PostFilterMode { filterMode }

    private func handleLink(_ url: URL) {
        let path = url.absoluteString
        if path.contains("linux.do/t/"), let range = path.range(of: "/t/", options: .backwards) {
            let remainder = String(path[range.upperBound...])
            let parts = remainder.split(separator: "/").map(String.init)
            if let slug = parts.first, let idStr = parts.dropFirst().first, let id = Int(idStr) {
                navigatedTopicID = id
                navigatedTopicTitle = slug.replacingOccurrences(of: "-", with: " ")
                return
            }
        }
        UIApplication.shared.open(url)
    }

    private func filterModeIcon() -> String {
        switch filterMode {
        case .hotOnly: return "flame.fill"
        case .authorOnly: return "person.fill"
        case .topLevelOnly: return "arrow.triangle.branch"
        case .all: return "line.3.horizontal.decrease.circle"
        }
    }
}
