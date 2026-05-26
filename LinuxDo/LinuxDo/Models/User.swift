//
//  User.swift
//  LinuxDo
//
//  用户数据模型
//

import Foundation

struct User: Codable, Identifiable {
    let id: Int
    let username: String
    let name: String?
    let avatarTemplate: String?
    let animatedAvatar: String?
    let trustLevel: Int
    let bioCooked: String?
    let bioRaw: String?
    let unreadNotifications: Int
    let unreadHighPriorityNotifications: Int
    let allUnreadNotificationsCount: Int
    let seenNotificationID: Int
    let status: UserStatus?
    let lastPostedAt: Date?
    let lastSeenAt: Date?
    let createdAt: Date?
    let location: String?
    let website: String?
    let flairURL: String?
    let flairName: String?
    let flairBgColor: String?
    let flairColor: String?
    let gamificationScore: Int?
    let canSendPrivateMessages: Bool?

    var trustLevelDescription: String {
        switch trustLevel {
        case 0: return "访客"
        case 1: return "成员"
        case 2: return "活跃成员"
        case 3: return "资深成员"
        case 4: return "领袖"
        default: return "TL\(trustLevel)"
        }
    }

    var avatarURL: URL? {
        if let anim = animatedAvatar, !anim.isEmpty {
            return URLHelper.resolve(anim)
        }
        guard let tpl = avatarTemplate else { return nil }
        return URLHelper.avatarURL(template: tpl, size: 120)
    }

    enum CodingKeys: String, CodingKey {
        case id, username, name, location, website
        case avatarTemplate = "avatar_template"
        case animatedAvatar = "animated_avatar"
        case trustLevel = "trust_level"
        case bioCooked = "bio_cooked"
        case bioRaw = "bio_raw"
        case unreadNotifications = "unread_notifications"
        case unreadHighPriorityNotifications = "unread_high_priority_notifications"
        case allUnreadNotificationsCount = "all_unread_notifications_count"
        case seenNotificationID = "seen_notification_id"
        case status
        case lastPostedAt = "last_posted_at"
        case lastSeenAt = "last_seen_at"
        case createdAt = "created_at"
        case flairURL = "flair_url"
        case flairName = "flair_name"
        case flairBgColor = "flair_bg_color"
        case flairColor = "flair_color"
        case gamificationScore = "gamification_score"
        case canSendPrivateMessages = "can_send_private_messages"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id) ?? 0
        username = try c.decodeIfPresent(String.self, forKey: .username) ?? ""
        name = try c.decodeIfPresent(String.self, forKey: .name)
        avatarTemplate = try c.decodeIfPresent(String.self, forKey: .avatarTemplate)
        animatedAvatar = try c.decodeIfPresent(String.self, forKey: .animatedAvatar)
        trustLevel = try c.decodeIfPresent(Int.self, forKey: .trustLevel) ?? 0
        bioCooked = try c.decodeIfPresent(String.self, forKey: .bioCooked)
        bioRaw = try c.decodeIfPresent(String.self, forKey: .bioRaw)
        unreadNotifications = try c.decodeIfPresent(Int.self, forKey: .unreadNotifications) ?? 0
        unreadHighPriorityNotifications = try c.decodeIfPresent(Int.self, forKey: .unreadHighPriorityNotifications) ?? 0
        allUnreadNotificationsCount = try c.decodeIfPresent(Int.self, forKey: .allUnreadNotificationsCount) ?? 0
        seenNotificationID = try c.decodeIfPresent(Int.self, forKey: .seenNotificationID) ?? 0
        status = try c.decodeIfPresent(UserStatus.self, forKey: .status)
        lastPostedAt = TimeUtils.parseUTC(try c.decodeIfPresent(String.self, forKey: .lastPostedAt))
        lastSeenAt = TimeUtils.parseUTC(try c.decodeIfPresent(String.self, forKey: .lastSeenAt))
        createdAt = TimeUtils.parseUTC(try c.decodeIfPresent(String.self, forKey: .createdAt))
        location = try c.decodeIfPresent(String.self, forKey: .location)
        website = try c.decodeIfPresent(String.self, forKey: .website)
        flairURL = try c.decodeIfPresent(String.self, forKey: .flairURL)
        flairName = try c.decodeIfPresent(String.self, forKey: .flairName)
        flairBgColor = try c.decodeIfPresent(String.self, forKey: .flairBgColor)
        flairColor = try c.decodeIfPresent(String.self, forKey: .flairColor)
        gamificationScore = try c.decodeIfPresent(Int.self, forKey: .gamificationScore)
        canSendPrivateMessages = try c.decodeIfPresent(Bool.self, forKey: .canSendPrivateMessages)
    }
}

// MARK: - UserStatus

struct UserStatus: Codable {
    let description: String?
    let emoji: String?
}

// MARK: - CurrentUser

struct CurrentUserResponse: Codable {
    let currentUser: User?

    enum CodingKeys: String, CodingKey {
        case currentUser = "current_user"
    }
}

// MARK: - UserSummary

struct UserSummary: Codable {
    let daysVisited: Int
    let postsReadCount: Int
    let likesReceived: Int
    let likesGiven: Int
    let topicCount: Int
    let postCount: Int
    let timeRead: Int
    let bookmarkCount: Int
    let topicsEntered: Int
    let recentTimeRead: Int

    var formattedTimeRead: String {
        let h = timeRead / 3600
        if h > 0 { return "\(h)h" }
        return "\(timeRead / 60)m"
    }

    enum CodingKeys: String, CodingKey {
        case daysVisited = "days_visited"
        case postsReadCount = "posts_read_count"
        case likesReceived = "likes_received"
        case likesGiven = "likes_given"
        case topicCount = "topic_count"
        case postCount = "post_count"
        case timeRead = "time_read"
        case bookmarkCount = "bookmark_count"
        case topicsEntered = "topics_entered"
        case recentTimeRead = "recent_time_read"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // user_summary 嵌套在 user_summary key 下
        let c: KeyedDecodingContainer<CodingKeys>
        if let nested = try? decoder.container(keyedBy: CodingKeys.self) {
            c = nested
        } else if let root = try? decoder.container(keyedBy: RootKeys.self),
                  let summary = try? root.nestedContainer(keyedBy: CodingKeys.self, forKey: .userSummary) {
            c = summary
        } else {
            c = container
        }
        daysVisited = try c.decodeIfPresent(Int.self, forKey: .daysVisited) ?? 0
        postsReadCount = try c.decodeIfPresent(Int.self, forKey: .postsReadCount) ?? 0
        likesReceived = try c.decodeIfPresent(Int.self, forKey: .likesReceived) ?? 0
        likesGiven = try c.decodeIfPresent(Int.self, forKey: .likesGiven) ?? 0
        topicCount = try c.decodeIfPresent(Int.self, forKey: .topicCount) ?? 0
        postCount = try c.decodeIfPresent(Int.self, forKey: .postCount) ?? 0
        timeRead = try c.decodeIfPresent(Int.self, forKey: .timeRead) ?? 0
        bookmarkCount = try c.decodeIfPresent(Int.self, forKey: .bookmarkCount) ?? 0
        topicsEntered = try c.decodeIfPresent(Int.self, forKey: .topicsEntered) ?? 0
        recentTimeRead = try c.decodeIfPresent(Int.self, forKey: .recentTimeRead) ?? 0
    }

    enum RootKeys: String, CodingKey {
        case userSummary = "user_summary"
    }
}
