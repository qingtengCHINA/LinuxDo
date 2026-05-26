//
//  SearchResult.swift
//  LinuxDo
//
//  搜索结果数据模型 — 对齐 fluxdo SearchResult
//

import Foundation

// MARK: - SearchResult

struct SearchResult: Codable {
    let posts: [SearchPost]?
    let topics: [Topic]?
    let users: [SearchUser]?
    let categories: [SearchCategory]?
    let groupedResult: GroupedSearchResult?

    var isEmpty: Bool {
        (posts ?? []).isEmpty && (users ?? []).isEmpty && (topics ?? []).isEmpty
    }
    var hasMorePosts: Bool { groupedResult?.moreFullPageResults == true || groupedResult?.morePosts == true }
    var hasMoreUsers: Bool { groupedResult?.moreUsers == true }

    enum CodingKeys: String, CodingKey {
        case posts, topics, users, categories
        case groupedResult = "grouped_search_result"
    }
}

// MARK: - SearchCategory (lightweight)

struct SearchCategory: Codable, Identifiable {
    let id: Int
    let name: String?
    let slug: String?
    let color: String?

    enum CodingKeys: String, CodingKey {
        case id, name, slug, color
    }
}

// MARK: - SearchPost

struct SearchPost: Codable, Identifiable {
    let id: Int
    let username: String
    let avatarTemplate: String
    let createdAt: Date?
    let likeCount: Int
    let blurb: String
    let postNumber: Int
    let topicTitleHeadline: String?
    let topicID: Int?
    let topicSlug: String?
    let topicTags: [Tag]?
    let categoryID: Int?

    var avatarURL: URL? {
        guard !avatarTemplate.isEmpty else { return nil }
        return URLHelper.avatarURL(template: avatarTemplate, size: 120)
    }

    var displayTitle: String {
        (topicTitleHeadline ?? "").strippingDiscourseMarkup()
    }

    var displayBlurb: String {
        blurb.strippingDiscourseMarkup()
    }

    enum CodingKeys: String, CodingKey {
        case id, username, blurb
        case avatarTemplate = "avatar_template"
        case createdAt = "created_at"
        case likeCount = "like_count"
        case postNumber = "post_number"
        case topicTitleHeadline = "topic_title_headline"
        case topicID = "topic_id"
        case topicSlug = "topic_slug"
        case topicTags = "topic_tags"
        case categoryID = "category_id"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id) ?? 0
        username = try c.decodeIfPresent(String.self, forKey: .username) ?? ""
        avatarTemplate = try c.decodeIfPresent(String.self, forKey: .avatarTemplate) ?? ""
        createdAt = TimeUtils.parseUTC(try c.decodeIfPresent(String.self, forKey: .createdAt))
        likeCount = try c.decodeIfPresent(Int.self, forKey: .likeCount) ?? 0
        blurb = try c.decodeIfPresent(String.self, forKey: .blurb) ?? ""
        postNumber = try c.decodeIfPresent(Int.self, forKey: .postNumber) ?? 0
        topicTitleHeadline = try c.decodeIfPresent(String.self, forKey: .topicTitleHeadline)
        topicID = try c.decodeIfPresent(Int.self, forKey: .topicID)
        topicSlug = try c.decodeIfPresent(String.self, forKey: .topicSlug)
        topicTags = try c.decodeIfPresent([Tag].self, forKey: .topicTags)
        categoryID = try c.decodeIfPresent(Int.self, forKey: .categoryID)
    }
}

// MARK: - SearchUser

struct SearchUser: Codable, Identifiable {
    let id: Int
    let username: String
    let name: String?
    let avatarTemplate: String

    var avatarURL: URL? {
        guard !avatarTemplate.isEmpty else { return nil }
        return URLHelper.avatarURL(template: avatarTemplate, size: 120)
    }

    enum CodingKeys: String, CodingKey {
        case id, username, name
        case avatarTemplate = "avatar_template"
    }
}

// MARK: - GroupedSearchResult

struct GroupedSearchResult: Codable {
    let term: String?
    let morePosts: Bool?
    let moreUsers: Bool?
    let moreCategories: Bool?
    let moreFullPageResults: Bool?

    enum CodingKeys: String, CodingKey {
        case term
        case morePosts = "more_posts"
        case moreUsers = "more_users"
        case moreCategories = "more_categories"
        case moreFullPageResults = "more_full_page_results"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        term = try c.decodeIfPresent(String.self, forKey: .term)
        morePosts = try c.decodeIfPresent(Bool.self, forKey: .morePosts)
        moreUsers = try c.decodeIfPresent(Bool.self, forKey: .moreUsers)
        moreCategories = try c.decodeIfPresent(Bool.self, forKey: .moreCategories)
        moreFullPageResults = try c.decodeIfPresent(Bool.self, forKey: .moreFullPageResults)
    }
}