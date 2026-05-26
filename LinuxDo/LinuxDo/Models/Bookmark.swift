//
//  Bookmark.swift
//  LinuxDo
//
//  书签数据模型 — 对齐 fluxdo Bookmark
//

import Foundation

struct Bookmark: Codable, Identifiable {
    let id: Int
    let userID: Int
    let topicID: Int
    let postNumber: Int?
    let name: String?
    let reminderAt: Date?
    let autoDeletePreference: Int
    let pinned: Bool
    let createdAt: Date?
    let updatedAt: Date?
    let topicTitle: String?
    let fancyTitle: String?
    let excerpt: String?

    var isPostBookmark: Bool { postNumber != nil && postNumber != 1 }

    enum CodingKeys: String, CodingKey {
        case id, name, pinned
        case userID = "user_id"
        case topicID = "topic_id"
        case postNumber = "post_number"
        case reminderAt = "reminder_at"
        case autoDeletePreference = "auto_delete_preference"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case topicTitle = "topic_title"
        case fancyTitle = "fancy_title"
        case excerpt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        userID = try c.decodeIfPresent(Int.self, forKey: .userID) ?? 0
        topicID = try c.decode(Int.self, forKey: .topicID)
        postNumber = try c.decodeIfPresent(Int.self, forKey: .postNumber)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        reminderAt = TimeUtils.parseUTC(try c.decodeIfPresent(String.self, forKey: .reminderAt))
        autoDeletePreference = try c.decodeIfPresent(Int.self, forKey: .autoDeletePreference) ?? 0
        pinned = try c.decodeIfPresent(Bool.self, forKey: .pinned) ?? false
        createdAt = TimeUtils.parseUTC(try c.decodeIfPresent(String.self, forKey: .createdAt))
        updatedAt = TimeUtils.parseUTC(try c.decodeIfPresent(String.self, forKey: .updatedAt))
        topicTitle = try c.decodeIfPresent(String.self, forKey: .topicTitle)
        fancyTitle = try c.decodeIfPresent(String.self, forKey: .fancyTitle)
        excerpt = try c.decodeIfPresent(String.self, forKey: .excerpt)
    }
}

struct BookmarkListResponse: Codable {
    let bookmarks: [Bookmark]
    let hasMore: Bool?

    enum CodingKeys: String, CodingKey {
        case bookmarks
        case hasMore = "no_results"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bookmarks = try c.decodeIfPresent([Bookmark].self, forKey: .bookmarks) ?? []
        // no_results == true means NO more results; invert
        let noResults = try c.decodeIfPresent(Bool.self, forKey: .hasMore) ?? true
        hasMore = !noResults
    }
}