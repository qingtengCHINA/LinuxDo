//
//  NotificationViewModel.swift
//  LinuxDo
//

import Foundation
import SwiftUI

@Observable
final class NotificationViewModel {
    private(set) var notifications: [AppNotification] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var unreadCount: Int = 0

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let resp = try await NotificationService.list()
            notifications = resp.notifications
            unreadCount = resp.totalRowsNotifications ?? 0
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markAllRead() async {
        do {
            try await NotificationService.markAllRead()
            unreadCount = 0
            // 本地标记
            for i in notifications.indices {
                notifications[i] = AppNotification(
                    id: notifications[i].id,
                    notificationType: notifications[i].notificationType,
                    read: true,
                    highPriority: notifications[i].highPriority,
                    createdAt: notifications[i].createdAt,
                    data: notifications[i].data,
                    actingUserID: notifications[i].actingUserID,
                    topicID: notifications[i].topicID,
                    postNumber: notifications[i].postNumber,
                    slug: notifications[i].slug,
                    fancyTitle: notifications[i].fancyTitle
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// 手动构造 init（因为 @Observable 移除 memberwise init）
extension AppNotification {
    init(id: Int, notificationType: Int, read: Bool, highPriority: Bool, createdAt: Date?, data: NotificationData?, actingUserID: Int?, topicID: Int?, postNumber: Int?, slug: String?, fancyTitle: String?) {
        self.id = id
        self.notificationType = notificationType
        self.read = read
        self.highPriority = highPriority
        self.createdAt = createdAt
        self.data = data
        self.actingUserID = actingUserID
        self.topicID = topicID
        self.postNumber = postNumber
        self.slug = slug
        self.fancyTitle = fancyTitle
    }
}
