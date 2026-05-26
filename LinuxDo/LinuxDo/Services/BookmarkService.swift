//
//  BookmarkService.swift
//  LinuxDo
//
//  书签服务 — 对齐 fluxdo 解析逻辑
//  /u/{username}/bookmarks.json 返回 user_bookmark_list 格式
//

import Foundation

@MainActor final class BookmarkService {
    static let shared = BookmarkService()
    private init() {}

    func bookmarks(page: Int = 1) async throws -> [Topic] {
        guard let username = SessionStore.shared.username else {
            throw APIError.notLoggedIn
        }
        let rawData = try await HTTPClient.shared.getRawData(
            "u/\(username)/bookmarks.json",
            query: page > 1 ? ["page": "\(page)"] : nil
        )
        let json = try JSONSerialization.jsonObject(with: rawData) as? [String: Any] ?? [:]
        return try parseBookmarkResponse(json)
    }

    func bookmarkTopic(topicID: Int) async throws -> Bookmark {
        let params: [String: String] = [
            "bookmarkable_id": "\(topicID)",
            "bookmarkable_type": "Topic"
        ]
        do {
            let bm: Bookmark = try await HTTPClient.shared.postForm("bookmarks.json", params: params)
            return bm
        } catch APIError.requestFailed(let code, let msg) where msg?.contains("bookmark") == true || msg?.contains("书签") == true {
            return try await fetchExistingBookmark(topicID: topicID)
        }
    }

    func bookmarkPost(postID: Int) async throws -> Bookmark {
        let params: [String: String] = [
            "bookmarkable_id": "\(postID)",
            "bookmarkable_type": "Post"
        ]
        do {
            let bm: Bookmark = try await HTTPClient.shared.postForm("bookmarks.json", params: params)
            return bm
        } catch APIError.requestFailed(let code, let msg) where msg?.contains("bookmark") == true || msg?.contains("书签") == true {
            return try await fetchExistingBookmark(topicID: nil, postID: postID)
        }
    }

    func findBookmarkID(topicID: Int) async throws -> Int? {
        guard let username = SessionStore.shared.username else { return nil }
        let rawData = try await HTTPClient.shared.getRawData("u/\(username)/bookmarks.json")
        let json = try JSONSerialization.jsonObject(with: rawData) as? [String: Any] ?? [:]
        guard let list = json["user_bookmark_list"] as? [String: Any],
              let bookmarks = list["bookmarks"] as? [[String: Any]] else { return nil }
        for bm in bookmarks {
            if bm["topic_id"] as? Int == topicID {
                return bm["id"] as? Int
            }
        }
        return nil
    }

    func findBookmarkID(postID: Int) async throws -> Int? {
        guard let username = SessionStore.shared.username else { return nil }
        let rawData = try await HTTPClient.shared.getRawData("u/\(username)/bookmarks.json")
        let json = try JSONSerialization.jsonObject(with: rawData) as? [String: Any] ?? [:]
        guard let list = json["user_bookmark_list"] as? [String: Any],
              let bookmarks = list["bookmarks"] as? [[String: Any]] else { return nil }
        for bm in bookmarks {
            if bm["bookmarkable_type"] as? String == "Post" && bm["bookmarkable_id"] as? Int == postID {
                return bm["id"] as? Int
            }
        }
        return nil
    }

    func deleteBookmark(id: Int) async throws {
        try await HTTPClient.shared.deleteVoid("bookmarks/\(id).json")
    }

    func updateBookmark(id: Int, name: String? = nil, reminderAt: String? = nil, autoDeletePreference: Int? = nil) async throws {
        var params: [(String, String)] = []
        if let name { params.append(("name", name)) }
        if let reminderAt { params.append(("reminder_at", reminderAt)) }
        if let autoDeletePreference { params.append(("auto_delete_preference", "\(autoDeletePreference)")) }
        try await HTTPClient.shared.putVoid("bookmarks/\(id).json", body: params.isEmpty ? nil : Dictionary(uniqueKeysWithValues: params))
    }

    private func fetchExistingBookmark(topicID: Int? = nil, postID: Int? = nil) async throws -> Bookmark {
        guard let username = SessionStore.shared.username else {
            throw APIError.notLoggedIn
        }
        let rawData = try await HTTPClient.shared.getRawData("u/\(username)/bookmarks.json")
        let json = try JSONSerialization.jsonObject(with: rawData) as? [String: Any] ?? [:]
        guard let list = json["user_bookmark_list"] as? [String: Any],
              let bookmarks = list["bookmarks"] as? [[String: Any]] else {
            throw APIError.requestFailed(0, "找不到现有书签")
        }
        for bm in bookmarks {
            if topicID != nil && bm["topic_id"] as? Int == topicID {
                return try JSONDecoder().decode(Bookmark.self, from: JSONSerialization.data(withJSONObject: bm))
            }
            if postID != nil {
                let bmPostID = bm["bookmarkable_id"] as? Int
                let bmType = bm["bookmarkable_type"] as? String
                if bmType == "Post" && bmPostID == postID {
                    return try JSONDecoder().decode(Bookmark.self, from: JSONSerialization.data(withJSONObject: bm))
                }
            }
        }
        throw APIError.requestFailed(0, "找不到现有书签")
    }

    private func parseBookmarkResponse(_ json: [String: Any]) throws -> [Topic] {
        guard let userBookmarkList = json["user_bookmark_list"] as? [String: Any] else {
            throw APIError.decodingFailed("No user_bookmark_list in response")
        }
        let bookmarkDicts = userBookmarkList["bookmarks"] as? [[String: Any]] ?? []

        var topics: [Topic] = []
        for bm in bookmarkDicts {
            var map = bm

            let bookmarkID = map["id"] as? Int ?? 0
            let bookmarkName = map["name"] as? String
            let bookmarkReminderAt = map["reminder_at"] as? String
            let bookmarkableType = map["bookmarkable_type"] as? String ?? "Topic"

            var bookmarkedPostNumber: Int? = nil
            if bookmarkableType == "Post",
               let linkedPostNumber = map["linked_post_number"] as? Int {
                bookmarkedPostNumber = linkedPostNumber
            }

            if let topicID = map["topic_id"] as? Int {
                map["id"] = topicID
            }
            if map["title"] == nil, let topicTitle = map["topic_title"] as? String {
                map["title"] = topicTitle
            }
            if map["fancy_title"] == nil, let topicTitle = map["topic_title"] as? String {
                map["fancy_title"] = topicTitle
            }
            if map["slug"] == nil {
                let title = (map["title"] as? String) ?? (map["topic_title"] as? String) ?? "topic"
                map["slug"] = String(title.lowercased()
                    .components(separatedBy: CharacterSet.alphanumerics.inverted)
                    .filter { !$0.isEmpty }
                    .joined(separator: "-")
                    .prefix(60))
            }
            if map["category_id"] == nil { map["category_id"] = 1 }
            if map["like_count"] == nil { map["like_count"] = 0 }
            if map["views"] == nil { map["views"] = 0 }
            if map["posts_count"] == nil { map["posts_count"] = 0 }
            if map["reply_count"] == nil { map["reply_count"] = 0 }
            if map["highest_post_number"] == nil { map["highest_post_number"] = 0 }
            if map["pinned"] == nil { map["pinned"] = false }
            if map["visible"] == nil { map["visible"] = true }
            if map["closed"] == nil { map["closed"] = false }
            if map["archived"] == nil { map["archived"] = false }
            if map["unseen"] == nil { map["unseen"] = false }
            if map["unread"] == nil { map["unread"] = 0 }
            if map["new_posts"] == nil { map["new_posts"] = 0 }
            if map["has_accepted_answer"] == nil { map["has_accepted_answer"] = false }
            if map["can_have_answer"] == nil { map["can_have_answer"] = false }
            if map["archetype"] == nil { map["archetype"] = "regular" }
            if map["pinned_globally"] == nil { map["pinned_globally"] = false }
            if map["tags"] == nil { map["tags"] = [] }
            if map["posters"] == nil { map["posters"] = [] }
            if let highest = map["highest_post_number"] as? Int, highest > 0 {
                if (map["posts_count"] as? Int) == nil { map["posts_count"] = highest }
                if (map["reply_count"] as? Int) == nil { map["reply_count"] = highest - 1 }
            }
            if map["last_posted_at"] == nil, let bumped = map["bumped_at"] {
                map["last_posted_at"] = bumped
            }
            if let userDict = map["user"] as? [String: Any],
               let userID = userDict["id"] as? Int {
                map["posters"] = [[
                    "user_id": userID,
                    "description": "Original Poster",
                    "extras": "latest"
                ] as [String: Any]]
                if let username = userDict["username"] as? String {
                    map["last_poster_username"] = username
                }
            }

            do {
                let topicData = try JSONSerialization.data(withJSONObject: map)
                var topic = try JSONDecoder().decode(Topic.self, from: topicData)
                topic.bookmarkID = bookmarkID
                topic.bookmarkName = bookmarkName
                topic.bookmarkReminderAt = TimeUtils.parseUTC(bookmarkReminderAt)
                topic.bookmarkedPostNumber = bookmarkedPostNumber
                topics.append(topic)
            } catch {
                // Skip bookmarks that fail to decode
            }
        }
        return topics
    }
}