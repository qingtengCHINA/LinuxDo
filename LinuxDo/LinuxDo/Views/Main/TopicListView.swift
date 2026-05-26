//
//  TopicListView.swift
//  LinuxDo
//
//  话题列表 — 复刻 fluxdo sort_and_tags_bar + topic list
//  衬线字体 · 筛选 pill · 下拉刷新 · 无限滚动 · 置顶折叠区
//

import SwiftUI

struct TopicListView: View {
    @State private var viewModel = TopicListViewModel()
    @State private var selectedFilter: TopicFilter = .latest
    @State private var pinnedExpanded = false

    enum TopicFilter: String, CaseIterable {
        case latest = "最新", hot = "热门", top = "精华"
    }

    private var pinnedTopics: [Topic] {
        viewModel.topics.filter { $0.pinned || $0.pinnedGlobally }
    }

    private var regularTopics: [Topic] {
        viewModel.topics.filter { !($0.pinned || $0.pinnedGlobally) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterBar
                incomingBanner
                topicContent
            }
            .navigationTitle("LinuxDo")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { Task { await viewModel.refresh() } }
                        label: { Image(systemName: "arrow.clockwise") }
                }
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink { CreateTopicPage() } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .task {
                await viewModel.loadLatest()
                viewModel.startRealtime()
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(TopicFilter.allCases, id: \.self) { f in
                    Button {
                        selectedFilter = f
                        Task {
                            switch f {
                            case .latest: await viewModel.loadLatest()
                            case .hot: await viewModel.loadTop(period: "daily")
                            case .top: await viewModel.loadTop(period: "weekly")
                            }
                        }
                    } label: {
                        Text(f.rawValue)
                            .font(DesignTypography.serifSubheadline).fontWeight(.medium)
                            .padding(.horizontal, 14).padding(.vertical, 6)
                            .background(Capsule().fill(selectedFilter == f ? Color.accentColor : Color(.tertiarySystemFill)))
                            .foregroundStyle(selectedFilter == f ? .white : .primary)
                    }
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
        }
    }

    @ViewBuilder
    private var incomingBanner: some View {
        if selectedFilter == .latest && viewModel.incomingCount > 0 {
            Button {
                Task {
                    await viewModel.loadLatest()
                    viewModel.clearIncoming()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up")
                    Text("查看 \(viewModel.incomingCount) 个新的或更新的话题")
                    Spacer()
                }
                .font(DesignTypography.serifSubheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.accentColor.opacity(0.12))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
        }
    }

    @ViewBuilder
    private var topicContent: some View {
        if viewModel.isLoading && viewModel.topics.isEmpty {
            Spacer(); ProgressView(); Spacer()
        } else if let err = viewModel.errorMessage, viewModel.topics.isEmpty {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "wifi.slash").font(.largeTitle).foregroundStyle(.secondary)
                Text(err).font(DesignTypography.serifBody).foregroundStyle(.secondary)
                Button("重试") { Task { await viewModel.refresh() } }.buttonStyle(.bordered)
            }
            Spacer()
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    let pinned = pinnedTopics
                    if !pinned.isEmpty {
                        pinnedSection(pinned)
                    }

                    ForEach(regularTopics) { t in
                        NavigationLink {
                            TopicDetailView(topicID: t.id, topicTitle: t.title)
                        } label: { TopicRowView(topic: t) }.buttonStyle(.plain)
                            .onAppear { if t.id == viewModel.topics.last?.id { Task { await viewModel.loadMore() } } }
                    }
                    if viewModel.isLoadingMore { ProgressView().padding() }
                }
                .padding(.vertical, 6)
            }
            .refreshable { await viewModel.refresh() }
        }
    }

    @ViewBuilder
    private func pinnedSection(_ pinned: [Topic]) -> some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { pinnedExpanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: "pin.fill").font(.system(size: 12)).foregroundStyle(.orange)
                    Text("置顶话题").font(DesignTypography.serifSubheadline).fontWeight(.semibold).foregroundStyle(.primary)
                    Text("\(pinned.count)").font(DesignTypography.serifCaption2).foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: pinnedExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Color(.secondarySystemGroupedBackground))
            }
            .buttonStyle(.plain)

            if pinnedExpanded {
                ForEach(pinned) { t in
                    NavigationLink {
                        TopicDetailView(topicID: t.id, topicTitle: t.title)
                    } label: { TopicRowView(topic: t) }.buttonStyle(.plain)
                }
            }

            Divider().padding(.horizontal, 16)
        }
        .animation(.easeInOut(duration: 0.25), value: pinnedExpanded)
    }
}
