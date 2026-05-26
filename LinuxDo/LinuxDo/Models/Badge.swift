//
//  Badge.swift
//  LinuxDo
//
//  徽章数据模型 — 对齐 fluxdo Badge/UserBadge
//

import Foundation

// MARK: - BadgeType

enum BadgeType: Int, Codable {
    case gold = 1
    case silver = 2
    case bronze = 3

    var label: String {
        switch self {
        case .gold: return "金牌"
        case .silver: return "银牌"
        case .bronze: return "铜牌"
        }
    }
}

// MARK: - Badge

struct Badge: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let badgeTypeID: Int
    let imageURL: String?
    let icon: String?
    let grantCount: Int
    let enabled: Bool
    let allowTitle: Bool
    let multipleGrant: Bool
    let longDescription: String?
    let slug: String
    let badgeGroupingID: Int?

    var badgeType: BadgeType { BadgeType(rawValue: badgeTypeID) ?? .bronze }

    enum CodingKeys: String, CodingKey {
        case id, name, description, icon, enabled, slug
        case badgeTypeID = "badge_type_id"
        case imageURL = "image_url"
        case grantCount = "grant_count"
        case allowTitle = "allow_title"
        case multipleGrant = "multiple_grant"
        case longDescription = "long_description"
        case badgeGroupingID = "badge_grouping_id"
    }
}

// MARK: - UserBadge

struct UserBadge: Codable, Identifiable {
    let id: Int
    let badgeID: Int
    let userID: Int
    let grantedAt: Date?
    let grantedByUsername: String?
    let postID: Int?
    let postNumber: Int?
    let topicID: Int?
    let topicTitle: String?
    let username: String?
    let count: Int
    let isFavorite: Bool?
    let canFavorite: Bool?
    let badge: Badge?

    enum CodingKeys: String, CodingKey {
        case id, count, username, badge
        case badgeID = "badge_id"
        case userID = "user_id"
        case grantedAt = "granted_at"
        case grantedByUsername = "granted_by_username"
        case postID = "post_id"
        case postNumber = "post_number"
        case topicID = "topic_id"
        case topicTitle = "topic_title"
        case isFavorite = "is_favorite"
        case canFavorite = "can_favorite"
    }
}

// MARK: - UserBadgeResponse

struct UserBadgeResponse: Codable {
    let userBadges: [UserBadge]
    let badges: [Badge]?

    enum CodingKeys: String, CodingKey {
        case userBadges = "user_badges"
        case badges
    }
}