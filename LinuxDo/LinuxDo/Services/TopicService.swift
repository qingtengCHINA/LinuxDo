//
//  TopicService.swift
//  LinuxDo
//
//  话题列表、详情 API
//

import Foundation

struct TopicService {

    /// 获取最新话题
    static func latest(page: Int = 0) async throws -> TopicListResponse {
        try await HTTPClient.shared.get("latest.json", query: ["page": "\(page)"])
    }

    /// 获取热门话题
    static func top(period: String = "daily", page: Int = 0) async throws -> TopicListResponse {
        try await HTTPClient.shared.get("top.json", query: ["period": period, "page": "\(page)"])
    }

    /// 获取分类下的话题
    static func category(slug: String, page: Int = 0) async throws -> TopicListResponse {
        try await HTTPClient.shared.get("c/\(slug).json", query: ["page": "\(page)"])
    }

    /// 获取标签下的话题
    static func tag(_ tagSlug: String, page: Int = 0) async throws -> TopicListResponse {
        try await HTTPClient.shared.get("tag/\(tagSlug).json", query: ["page": "\(page)"])
    }

    /// 获取话题详情（通过 id）
    static func detail(id: Int) async throws -> TopicDetail {
        try await HTTPClient.shared.get("t/\(id).json")
    }

    /// 获取话题详情（通过 slug + id）
    static func detail(slug: String, id: Int, page: Int = 1) async throws -> TopicDetail {
        try await HTTPClient.shared.get("t/\(slug)/\(id).json", query: ["page": "\(page)"])
    }

    /// 搜索
    static func search(query: String, page: Int = 1) async throws -> SearchResponse {
        try await HTTPClient.shared.get("search.json", query: ["q": query, "page": "\(page)"])
    }
}
