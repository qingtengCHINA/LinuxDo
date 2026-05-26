//
//  TopicDetailViewModel.swift
//  LinuxDo
//
//  话题详情 ViewModel — 加载帖子流、翻页、书签、点赞
//

import Foundation
import SwiftUI

@Observable
final class TopicDetailViewModel {
    private(set) var detail: TopicDetail?
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var errorMessage: String?
    private(set) var isBookmarked = false
    private(set) var bookmarkID: Int?
    private(set) var hasLiveUpdates = false
    private(set) var liveUpdateText: String?
    var currentPostIndex: Int = 0
    var replyError: String?

    var posts: [Post] { detail?.postStream.posts ?? [] }

    private var realtimeTopicID: Int?
    private var realtimeTokens: [UUID] = []

    deinit {
        let tokens = realtimeTokens
        Task { @MainActor in
            for token in tokens {
                MessageBusService.shared.unsubscribe(token)
            }
        }
    }

    // MARK: - Load

    func load(topicID: Int) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            apply(try await TopicService.detail(id: topicID))
            startRealtime(topicID: topicID)
        } catch {
            print("❌ TopicDetailVM.load(id=\(topicID)): \(error)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Pagination

    func loadMore() async {
        guard let detail = detail, !isLoadingMore else { return }
        let currentCount = detail.postStream.posts.count
        let totalPosts = detail.postsCount
        guard currentCount < totalPosts else { return }

        let chunkSize = 20
        let postNumbers = detail.postStream.stream
        let loadedSet = Set(detail.postStream.posts.map(\.postNumber))
        let toLoad = postNumbers.filter { !loadedSet.contains($0) }
        guard !toLoad.isEmpty else { return }

        let batch = Array(toLoad.prefix(chunkSize))
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let idsParam = batch.map(\.description).joined(separator: ",")
            let newDetail = try await TopicService.detail(id: detail.id)
            var mergedPosts = detail.postStream.posts
            let existingIDs = Set(mergedPosts.map(\.id))
            for p in newDetail.postStream.posts where !existingIDs.contains(p.id) {
                mergedPosts.append(p)
            }
            mergedPosts.sort { $0.postNumber < $1.postNumber }
            self.detail?.postStream = PostStream(
                posts: mergedPosts,
                stream: detail.postStream.stream,
                gaps: newDetail.postStream.gaps
            )
        } catch {
            // Silent fail for pagination
        }
    }

    // MARK: - Actions

    func reply(raw: String, replyToPostNumber: Int? = nil) async -> Post? {
        guard let topicID = detail?.id else { return nil }
        do {
            replyError = nil
            let post = try await PostService.reply(topicID: topicID, raw: raw, replyToPostNumber: replyToPostNumber)
            await refresh()
            return post
        } catch {
            replyError = error.localizedDescription
            return nil
        }
    }

    func like(postID: Int) async {
        do {
            let _ = try await PostService.like(postID: postID)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleBookmark() async {
        guard let topicID = detail?.id else { return }
        do {
            if isBookmarked {
                var bid = bookmarkID
                if bid == nil {
                    bid = try await BookmarkService.shared.findBookmarkID(topicID: topicID)
                }
                guard let deleteID = bid else { return }
                try await BookmarkService.shared.deleteBookmark(id: deleteID)
                isBookmarked = false
                bookmarkID = nil
            } else {
                let bm = try await BookmarkService.shared.bookmarkTopic(topicID: topicID)
                isBookmarked = true
                bookmarkID = bm.id
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func togglePostBookmark(post: Post) async {
        do {
            if post.bookmarked {
                var bid = post.bookmarkableID
                if bid == nil {
                    bid = try await BookmarkService.shared.findBookmarkID(postID: post.id)
                }
                guard let deleteID = bid else { return }
                try await BookmarkService.shared.deleteBookmark(id: deleteID)
            } else {
                let bm = try await BookmarkService.shared.bookmarkPost(postID: post.id)
                isBookmarked = true
                bookmarkID = bm.id
            }
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refresh() async {
        guard let id = detail?.id else { return }
        await load(topicID: id)
    }

    func votePoll(_ payload: PollVotePayload) async {
        do {
            _ = try await PostService.votePoll(postID: payload.postID, pollName: payload.pollName, options: payload.options)
            await refreshSilently()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removePollVote(_ payload: PollVotePayload) async {
        do {
            _ = try await PostService.removePollVote(postID: payload.postID, pollName: payload.pollName)
            await refreshSilently()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearLiveUpdateNotice() {
        hasLiveUpdates = false
        liveUpdateText = nil
    }

    private func apply(_ newDetail: TopicDetail) {
        detail = newDetail
        isBookmarked = newDetail.bookmarkableID != nil || newDetail.bookmarked
        bookmarkID = newDetail.bookmarkableID
    }

    private func refreshSilently() async {
        guard let id = detail?.id else { return }
        do {
            apply(try await TopicService.detail(id: id))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func startRealtime(topicID: Int) {
        guard realtimeTopicID != topicID else { return }
        for token in realtimeTokens {
            MessageBusService.shared.unsubscribe(token)
        }
        realtimeTokens.removeAll()
        realtimeTopicID = topicID

        realtimeTokens.append(MessageBusService.shared.subscribe("/topic/\(topicID)") { [weak self] message in
            self?.handleTopicMessage(message)
        })
        realtimeTokens.append(MessageBusService.shared.subscribe("/topic/\(topicID)/reactions") { [weak self] message in
            self?.handleTopicMessage(message)
        })
    }

    private func handleTopicMessage(_ message: MessageBusMessage) {
        let data = message.data

        if data["reload_topic"]?.boolValue == true {
            liveUpdateText = "话题状态已更新"
            hasLiveUpdates = true
            Task { await refreshSilently() }
            return
        }

        let type = data["type"]?.stringValue
        switch type {
        case "created":
            liveUpdateText = "收到新回复，已自动刷新"
            hasLiveUpdates = true
            Task { await refreshSilently() }
        case "revised", "rebaked", "deleted", "destroyed", "recovered", "acted", "liked", "unliked", "boost_added", "boost_removed", "policy_change":
            liveUpdateText = "帖子内容已更新"
            hasLiveUpdates = true
            Task { await refreshSilently() }
        default:
            break
        }
    }
}
