//
//  ContentView.swift
//  LinuxDo
//
//  主 TabView — 5 个标签：最新/搜索/分类/书签/我的
//

import SwiftUI

struct ContentView: View {
    @State private var authVM = AuthViewModel()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            TopicListView()
                .tabItem { Label("最新", systemImage: "list.bullet") }.tag(0)

            SearchView()
                .tabItem { Label("搜索", systemImage: "magnifyingglass") }.tag(1)

            CategoryListView()
                .tabItem { Label("分类", systemImage: "square.grid.2x2") }.tag(2)

            BookmarkListView()
                .tabItem { Label("书签", systemImage: "bookmark") }.tag(3)

            ProfileView()
                .tabItem { Label("我的", systemImage: "person.crop.circle") }.tag(4)
        }
        .environment(authVM)
        .task { await authVM.restoreSession() }
    }
}

// MARK: - Category List

struct CategoryListView: View {
    @State private var categories: [DiscourseCategory] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading { ProgressView() }
                else if let err = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "wifi.slash").font(.largeTitle).foregroundStyle(.secondary)
                        Text(err).foregroundStyle(.secondary)
                        Button("重试") { Task { await load() } }
                    }
                } else {
                    List(categories) { cat in
                        NavigationLink {
                            CategoryTopicListView(category: cat)
                        } label: {
                            HStack(spacing: 12) {
                                Circle().fill(Color(hex: cat.hexColor) ?? .accentColor).frame(width: 12, height: 12)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cat.name).font(DesignTypography.serifBody).fontWeight(.medium)
                                    if let d = cat.descriptionExcerpt, !d.isEmpty {
                                        Text(d).font(DesignTypography.serifCaption).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                }
                                Spacer()
                                Text("\(cat.topicCount)").font(DesignTypography.serifCaption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .listStyle(.plain).refreshable { await load() }
                }
            }
            .navigationTitle("分类").task { await load() }
        }
    }

    private func load() async {
        isLoading = true; errorMessage = nil; defer { isLoading = false }
        do { categories = try await CategoryService.list().categoryList.categories.filter { !$0.readRestricted } }
        catch { errorMessage = error.localizedDescription }
    }
}

struct CategoryTopicListView: View {
    let category: DiscourseCategory
    @State private var viewModel = TopicListViewModel()

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.topics) { t in
                    NavigationLink {
                        TopicDetailView(topicID: t.id, topicTitle: t.title)
                    } label: { TopicRowView(topic: t) }.buttonStyle(.plain)
                }
                if viewModel.isLoadingMore { ProgressView().padding() }
            }
        }
        .navigationTitle(category.name)
        .refreshable { await viewModel.refresh() }
        .task { await viewModel.loadCategory(slug: category.slug) }
    }
}