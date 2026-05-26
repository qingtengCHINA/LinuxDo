//
//  SearchService.swift
//  LinuxDo
//

import Foundation

@MainActor final class SearchService {
    static let shared = SearchService()
    private init() {}

    func search(query: String, page: Int = 1, categoryID: Int? = nil, order: SearchOrder? = nil, status: SearchStatus? = nil, tags: [String]? = nil) async throws -> SearchResult {
        var queryItems: [String: String] = ["q": query]
        if page > 1 { queryItems["page"] = "\(page)" }
        if let categoryID { queryItems["category"] = "\(categoryID)" }
        if let order { queryItems["order"] = order.rawValue }
        if let status { queryItems["status"] = status.rawValue }
        if let tags, !tags.isEmpty {
            // Discourse search uses tags parameter with comma-separated values
            queryItems["tags"] = tags.joined(separator: ",")
        }
        return try await HTTPClient.shared.get("search.json", query: queryItems)
    }
}

enum SearchOrder: String, CaseIterable {
    case latest = "latest"
    case likes = "likes"
    case views = "views"
    case replies = "replies"

    var displayName: String {
        switch self {
        case .latest: return "最新"
        case .likes: return "最多点赞"
        case .views: return "最多浏览"
        case .replies: return "最多回复"
        }
    }
}

enum SearchStatus: String, CaseIterable {
    case open = "open"
    case closed = "closed"
    case publicTopic = "public"
    case pinned = "pinned"

    var displayName: String {
        switch self {
        case .open: return "开放"
        case .closed: return "已关闭"
        case .publicTopic: return "公开"
        case .pinned: return "置顶"
        }
    }
}