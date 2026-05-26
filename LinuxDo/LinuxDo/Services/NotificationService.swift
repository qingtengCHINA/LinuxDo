//
//  NotificationService.swift
//  LinuxDo
//
//  通知 API
//

import Foundation

struct NotificationService {

    /// 获取通知列表
    static func list(page: Int = 0) async throws -> NotificationListResponse {
        try await HTTPClient.shared.get("notifications.json", query: ["page": "\(page)"])
    }

    /// 标记所有通知为已读
    static func markAllRead() async throws {
        struct Empty: Decodable {}
        struct Body: Encodable {}
        let _: Empty = try await HTTPClient.shared.put("notifications/mark-read.json", body: Body())
    }
}
