//
//  TopicListViewModel.swift
//  LinuxDo
//
//  话题列表 ViewModel
//  支持分页加载、排序切换（最新/热门/分类）
//

import Foundation
import SwiftUI

@Observable
final class TopicListViewModel {
    private(set) var topics: [Topic] = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var errorMessage: String?
    private(set) var hasMore = true
    private(set) var incomingTopicIDs: Set<Int> = []

    private var currentPage = 0
    private var filterMode: FilterMode = .latest
    private var realtimeTokens: [UUID] = []

    var incomingCount: Int { incomingTopicIDs.count }

    deinit {
        let tokens = realtimeTokens
        Task { @MainActor in
            for token in tokens {
                MessageBusService.shared.unsubscribe(token)
            }
        }
    }

    enum FilterMode: Equatable {
        case latest
        case top(period: String)
        case category(slug: String)
        case tag(String)
    }

    // MARK: - Actions

    func loadLatest() async {
        filterMode = .latest
        await refresh()
    }

    func loadTop(period: String = "daily") async {
        filterMode = .top(period: period)
        await refresh()
    }

    func loadCategory(slug: String) async {
        filterMode = .category(slug: slug)
        await refresh()
    }

    func loadTag(_ slug: String) async {
        filterMode = .tag(slug)
        await refresh()
    }

    func loadMyTopics() async {
        guard let username = SessionStore.shared.username else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let resp = try await UserService.shared.userTopics(username: username)
            topics = resp.topicList.topics
            hasMore = resp.topicList.moreTopicsURL != nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refresh() async {
        currentPage = 0
        hasMore = true
        incomingTopicIDs.removeAll()
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let resp: TopicListResponse = try await fetch(page: 0)
            topics = resp.topicList.topics
            hasMore = resp.topicList.moreTopicsURL != nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMore() async {
        guard !isLoadingMore, hasMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        let nextPage = currentPage + 1
        do {
            let resp: TopicListResponse = try await fetch(page: nextPage)
            topics.append(contentsOf: resp.topicList.topics)
            hasMore = resp.topicList.moreTopicsURL != nil
            currentPage = nextPage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startRealtime() {
        guard realtimeTokens.isEmpty else { return }

        let callback: MessageBusCallback = { [weak self] message in
            self?.handleRealtimeMessage(message)
        }
        realtimeTokens.append(MessageBusService.shared.subscribe("/latest", callback: callback))
        realtimeTokens.append(MessageBusService.shared.subscribe("/new", callback: callback))
    }

    func clearIncoming() {
        incomingTopicIDs.removeAll()
    }

    // MARK: - Private

    private func fetch(page: Int) async throws -> TopicListResponse {
        switch filterMode {
        case .latest:
            return try await TopicService.latest(page: page)
        case .top(let period):
            return try await TopicService.top(period: period, page: page)
        case .category(let slug):
            return try await TopicService.category(slug: slug, page: page)
        case .tag(let slug):
            return try await TopicService.tag(slug, page: page)
        }
    }

    private func handleRealtimeMessage(_ message: MessageBusMessage) {
        guard case .latest = filterMode else { return }
        let messageType = message.data["message_type"]?.stringValue
        guard messageType == "latest" || messageType == "new_topic",
              let topicID = message.data["topic_id"]?.intValue
        else { return }

        incomingTopicIDs.insert(topicID)
    }
}
