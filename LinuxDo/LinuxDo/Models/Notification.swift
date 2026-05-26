//
//  Notification.swift
//  LinuxDo
//
//  通知数据模型
//

import Foundation

struct AppNotification: Codable, Identifiable {
    let id: Int
    let notificationType: Int
    let read: Bool
    let highPriority: Bool
    let createdAt: Date?
    let data: NotificationData?
    let actingUserID: Int?
    let topicID: Int?
    let postNumber: Int?
    let slug: String?
    let fancyTitle: String?

    enum CodingKeys: String, CodingKey {
        case id, read, slug
        case notificationType = "notification_type"
        case highPriority = "high_priority"
        case createdAt = "created_at"
        case data
        case actingUserID = "acting_user_id"
        case topicID = "topic_id"
        case postNumber = "post_number"
        case fancyTitle = "fancy_title"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        notificationType = try c.decode(Int.self, forKey: .notificationType)
        read = try c.decode(Bool.self, forKey: .read)
        highPriority = try c.decodeIfPresent(Bool.self, forKey: .highPriority) ?? false
        createdAt = TimeUtils.parseUTC(try c.decodeIfPresent(String.self, forKey: .createdAt))
        data = try c.decodeIfPresent(NotificationData.self, forKey: .data)
        actingUserID = try c.decodeIfPresent(Int.self, forKey: .actingUserID)
        topicID = try c.decodeIfPresent(Int.self, forKey: .topicID)
        postNumber = try c.decodeIfPresent(Int.self, forKey: .postNumber)
        slug = try c.decodeIfPresent(String.self, forKey: .slug)
        fancyTitle = try c.decodeIfPresent(String.self, forKey: .fancyTitle)
    }
}

struct NotificationData: Codable {
    let badgeID: Int?
    let badgeName: String?
    let displayUsername: String?
    let groupName: String?
    let message: String?
    let originalUsername: String?
    let topicTitle: String?
    let username: String?
    let username2: String?

    enum CodingKeys: String, CodingKey {
        case badgeID = "badge_id"
        case badgeName = "badge_name"
        case displayUsername = "display_username"
        case groupName = "group_name"
        case message
        case originalUsername = "original_username"
        case topicTitle = "topic_title"
        case username, username2
    }
}

struct NotificationListResponse: Codable {
    let notifications: [AppNotification]
    let totalRowsNotifications: Int?
    let seenNotificationID: Int?

    enum CodingKeys: String, CodingKey {
        case notifications
        case totalRowsNotifications = "total_rows_notifications"
        case seenNotificationID = "seen_notification_id"
    }
}
