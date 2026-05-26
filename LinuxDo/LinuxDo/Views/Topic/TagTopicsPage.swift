//
//  TagTopicsPage.swift
//  LinuxDo
//
//  标签话题列表 — 对照 fluxdo tag_topics_page
//

import SwiftUI

struct TagTopicsPage: View {
    let tag: String
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
        .navigationTitle("#\(tag)")
        .refreshable { await viewModel.refresh() }
        .task { await viewModel.loadTag(tag) }
        .overlay {
            if viewModel.isLoading && viewModel.topics.isEmpty { ProgressView() }
            if let err = viewModel.errorMessage, viewModel.topics.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundStyle(.secondary)
                    Text(err).font(DesignTypography.serifBody).foregroundStyle(.secondary)
                    Button("重试") { Task { await viewModel.loadTag(tag) } }.buttonStyle(.bordered)
                }
            }
        }
    }
}