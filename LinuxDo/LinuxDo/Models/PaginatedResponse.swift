//
//  PaginatedResponse.swift
//  LinuxDo
//
//  Discourse API 通用分页响应包装
//

import Foundation

/// 话题列表响应
struct TopicListResponse: Codable {
    let topicList: TopicList

    enum CodingKeys: String, CodingKey {
        case topicList = "topic_list"
    }
}

struct TopicList: Codable {
    let topics: [Topic]
    let moreTopicsURL: String?
    let totalRows: Int?

    enum CodingKeys: String, CodingKey {
        case topics
        case moreTopicsURL = "more_topics_url"
        case totalRows = "total_rows"
    }
}

struct PostActionResponse: Codable {
    let id: Int?
    let name: String?
    let postActionTypeID: Int?

    enum CodingKeys: String, CodingKey {
        case id, name
        case postActionTypeID = "post_action_type_id"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        postActionTypeID = try c.decodeIfPresent(Int.self, forKey: .postActionTypeID)
    }
}

/// 搜索响应
struct SearchResponse: Codable {
    let topics: [Topic]?
    let posts: [Post]?
    let users: [User]?
}
