//
//  PostService.swift
//  LinuxDo
//
//  帖子操作：回复、点赞、书签
//

import Foundation

@MainActor
struct PostService {

    /// 创建回复 — 使用 form-urlencoded（Discourse 要求）
    static func reply(topicID: Int, raw: String, replyToPostNumber: Int? = nil) async throws -> Post {
        var params: [String: String] = [
            "topic_id": "\(topicID)",
            "raw": raw
        ]
        if let r = replyToPostNumber {
            params["reply_to_post_number"] = "\(r)"
        }
        return try await HTTPClient.shared.postForm("posts.json", params: params)
    }

    /// 点赞帖子 — form-urlencoded
    static func like(postID: Int) async throws -> PostActionResponse {
        let params: [String: String] = [
            "id": "\(postID)",
            "post_action_type_id": "2"
        ]
        return try await HTTPClient.shared.postForm("post_actions.json", params: params)
    }

    /// 取消点赞 — DELETE with query param
    static func unlike(postActionID: Int) async throws {
        struct Empty: Decodable {}
        let _: Empty = try await HTTPClient.shared.delete("post_actions/\(postActionID).json", query: ["post_action_type_id": "2"])
    }

    /// 编辑帖子 — form-urlencoded
    static func edit(postID: Int, raw: String) async throws -> Post {
        try await HTTPClient.shared.putForm("posts/\(postID).json", params: ["post[raw]": raw])
    }

    /// 投票 — Discourse poll plugin uses repeated `options[]` keys.
    static func votePoll(postID: Int, pollName: String, options: [String]) async throws -> Poll? {
        var params: [(String, String)] = [
            ("post_id", "\(postID)"),
            ("poll_name", pollName)
        ]
        params.append(contentsOf: options.map { ("options[]", $0) })
        let response: PollVoteResponse = try await HTTPClient.shared.putForm("polls/vote", params: params)
        return response.poll
    }

    /// 撤销投票
    static func removePollVote(postID: Int, pollName: String) async throws -> Poll? {
        let response: PollVoteResponse = try await HTTPClient.shared.deleteForm("polls/vote", params: [
            ("post_id", "\(postID)"),
            ("poll_name", pollName)
        ])
        return response.poll
    }

    /// 删除帖子
    static func delete(postID: Int) async throws {
        struct Empty: Decodable {}
        let _: Empty = try await HTTPClient.shared.delete("posts/\(postID).json")
    }

    /// 添加话题书签 — form-urlencoded
    static func bookmarkTopic(topicID: Int) async throws -> Bookmark {
        let params: [String: String] = [
            "bookmarkable_id": "\(topicID)",
            "bookmarkable_type": "Topic"
        ]
        return try await HTTPClient.shared.postForm("bookmarks.json", params: params)
    }

    /// 删除书签
    static func deleteBookmark(id: Int) async throws {
        struct Empty: Decodable {}
        let _: Empty = try await HTTPClient.shared.delete("bookmarks/\(id).json")
    }
}

private struct PollVoteResponse: Decodable {
    let poll: Poll?
}
