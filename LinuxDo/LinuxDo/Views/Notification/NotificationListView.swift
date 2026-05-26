//
//  NotificationListView.swift
//  LinuxDo
//

import SwiftUI

struct NotificationListView: View {
    @State private var viewModel = NotificationViewModel()
    @State private var selectedFilter: NotificationFilter = .all

    enum NotificationFilter: String, CaseIterable {
        case all = "全部"
        case unread = "未读"
        case mentions = "提及"
        case replies = "回复"
        case likes = "赞"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterBar
                notificationContent
            }
            .navigationTitle("通知")
            .toolbar {
                if viewModel.unreadCount > 0 {
                    ToolbarItem(placement: .primaryAction) {
                        Button("全部已读") { Task { await viewModel.markAllRead() } }
                    }
                }
            }
            .task { await viewModel.load() }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(NotificationFilter.allCases, id: \.self) { f in
                    Button {
                        selectedFilter = f
                    } label: {
                        Text(f.rawValue)
                            .font(DesignTypography.serifSubheadline).fontWeight(.medium)
                            .padding(.horizontal, 14).padding(.vertical, 6)
                            .background(Capsule().fill(selectedFilter == f ? Color.accentColor : Color(.tertiarySystemFill)))
                            .foregroundStyle(selectedFilter == f ? .white : .primary)
                    }
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
        }
    }

    @ViewBuilder
    private var notificationContent: some View {
        let filtered = filteredNotifications
        if viewModel.isLoading && viewModel.notifications.isEmpty {
            Spacer(); ProgressView(); Spacer()
        } else if filtered.isEmpty {
            ContentUnavailableView("暂无通知", systemImage: "bell.slash", description: Text("新通知会显示在这里"))
        } else {
            List {
                ForEach(filtered) { notif in
                    NavigationLink {
                        if let tid = notif.topicID {
                            TopicDetailView(topicID: tid, topicTitle: notif.fancyTitle ?? notif.data?.topicTitle ?? "话题")
                        }
                    } label: { notificationRow(notif) }
                }
            }
            .listStyle(.plain)
            .refreshable { await viewModel.load() }
        }
    }

    private var filteredNotifications: [AppNotification] {
        switch selectedFilter {
        case .all: return viewModel.notifications
        case .unread: return viewModel.notifications.filter { !$0.read }
        case .mentions: return viewModel.notifications.filter { NotificationType.from($0.notificationType) == .mentioned }
        case .replies: return viewModel.notifications.filter {
            let t = NotificationType.from($0.notificationType)
            return t == .replied || t == .quoted
        }
        case .likes: return viewModel.notifications.filter {
            let t = NotificationType.from($0.notificationType)
            return t == .liked || t == .likedConsolidated || t == .reaction
        }
        }
    }

    private func notificationRow(_ n: AppNotification) -> some View {
        HStack(alignment: .top, spacing: 12) {
            notificationIcon(n.notificationType)
            VStack(alignment: .leading, spacing: 4) {
                Text(notificationTitle(n))
                    .font(DesignTypography.serifSubheadline)
                    .foregroundStyle(n.read ? .secondary : .primary)
                    .lineLimit(2)
                if let t = n.createdAt {
                    Text(TimeUtils.relative(from: t))
                        .font(DesignTypography.serifCaption).foregroundStyle(.tertiary)
                }
            }
            Spacer()
            if !n.read {
                Circle().fill(.blue).frame(width: 8, height: 8)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
        .opacity(n.read ? 0.7 : 1.0)
    }

    private func notificationIcon(_ type: Int) -> some View {
        let (name, color): (String, Color) = {
            switch NotificationType.from(type) {
            case .mentioned, .groupMentioned: return ("at.circle.fill", .blue)
            case .replied: return ("bubble.left.fill", .green)
            case .quoted: return ("quote.opening", .green)
            case .liked, .likedConsolidated: return ("heart.fill", .pink)
            case .privateMessage: return ("envelope.fill", .blue)
            case .invitedToTopic: return ("person.badge.plus", .blue)
            case .grantedBadge: return ("rosette", .yellow)
            case .bookmarkReminder: return ("bookmark.fill", .orange)
            case .reaction: return ("hand.thumbsup.fill", .purple)
            case .boost: return ("bolt.fill", .orange)
            case .following, .followingCreatedTopic, .followingReplied: return ("person.fill.checkmark", .blue)
            case .posted: return ("bubble.left", .green)
            case .linked: return ("link", .blue)
            default: return ("bell.fill", .gray)
            }
        }()
        return Image(systemName: name).font(.title3).foregroundStyle(color)
            .frame(width: 32, height: 32)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func notificationTitle(_ n: AppNotification) -> String {
        if let f = n.fancyTitle { return f }
        let d = n.data
        let u = d?.displayUsername ?? d?.username ?? "用户"
        switch NotificationType.from(n.notificationType) {
        case .mentioned: return "\(u) 提到了你"
        case .replied: return "\(u) 回复了你"
        case .quoted: return "\(u) 引用了你"
        case .liked: return "\(u) 赞了你的帖子"
        case .likedConsolidated: return "\(u) 和其他人赞了你的帖子"
        case .privateMessage: return "\(u) 给你发了私信"
        case .invitedToTopic: return "\(u) 邀请你加入话题"
        case .grantedBadge: return "获得徽章: \(d?.badgeName ?? "")"
        case .bookmarkReminder: return "书签提醒"
        case .reaction: return "\(u) 对你的帖子做出了反应"
        case .boost: return "\(u) 助推了你的帖子"
        case .following: return "\(u) 开始关注你"
        case .followingCreatedTopic: return "\(u) 创建了新话题"
        case .followingReplied: return "\(u) 回复了关注的话题"
        case .posted: return "\(u) 在话题中发帖"
        default: return d?.message ?? "新通知"
        }
    }
}

enum NotificationType: Int {
    case mentioned = 1, replied = 2, quoted = 3, edited = 4
    case liked = 5, privateMessage = 6, invitedToPrivateMessage = 7
    case inviteeAccepted = 8, posted = 9, movedPost = 10, linked = 11
    case grantedBadge = 12, invitedToTopic = 13, custom = 14
    case groupMentioned = 15, groupMessageSummary = 16
    case watchingFirstPost = 17, topicReminder = 18
    case likedConsolidated = 19, postApproved = 20
    case bookmarkReminder = 24, reaction = 25
    case boost = 43, following = 800
    case followingCreatedTopic = 801, followingReplied = 802
    case unknown = 0

    static func from(_ id: Int) -> NotificationType {
        NotificationType(rawValue: id) ?? .unknown
    }
}