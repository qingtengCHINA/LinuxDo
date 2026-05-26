//
//  TopicRowView.swift
//  LinuxDo
//

import SwiftUI

struct TopicRowView: View {
    let topic: Topic

    private var isUnread: Bool { topic.unseen || topic.unread > 0 }
    private var isFullyRead: Bool { !topic.unseen && topic.unread == 0 && topic.lastReadPostNumber != nil }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            posterAvatar
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 5) {
                titleRow
                tagAndCategoryRow
                excerptRow
                bottomStatsRow
            }
        }
        .padding(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 14))
        .opacity(isFullyRead && !isUnread ? 0.5 : 1.0)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemGroupedBackground)))
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    // MARK: - Poster Avatar (left column)

    private var posterAvatar: some View {
        Group {
            if let poster = topic.posters.first, let avatarURL = poster.user?.avatarURL {
                AvatarView(url: avatarURL, size: 40)
            } else {
                Circle()
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: 40, height: 40)
                    .overlay(Image(systemName: "person.fill").font(.caption).foregroundStyle(.secondary))
            }
        }
    }

    // MARK: - Title Row with icons + unread dot + reply count

    private var titleRow: some View {
        HStack(alignment: .top, spacing: 4) {
            // Status icons before title
            HStack(spacing: 3) {
                if topic.closed {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                if topic.hasAcceptedAnswer {
                    Image(systemName: "checkmark.square.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.green)
                } else if topic.canHaveAnswer {
                    Image(systemName: "square")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                }
                if topic.pinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.orange)
                }
            }

            // Title text with emoji support (fancy_title contains emoji shortcodes)
            Text((topic.fancyTitle ?? topic.title).strippingDiscourseMarkup())
                .font(DesignTypography.serifSubheadline).fontWeight(.semibold)
                .foregroundStyle(isUnread ? .primary : .secondary)
                .lineLimit(2)

            Spacer(minLength: 4)

            // Reply count badge on the right
            if topic.replyCount > 0 || topic.unread > 0 {
                replyBadge
            }
        }
    }

    private var replyBadge: some View {
        Group {
            if topic.unread > 0 {
                // Unread count — blue badge like fluxdo
                Text("\(topic.unread)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(Color.accentColor))
            } else if topic.replyCount > 0 {
                // Plain reply count
                Text("\(topic.replyCount)")
                    .font(DesignTypography.serifCaption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 2)
    }

    // MARK: - Category + Tags Row

    private var tagAndCategoryRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                // Category badge if we had category data — shown as color dot + name
                // (We'll add category lookup later; for now use the ID-based approach)
                if !topic.tags.isEmpty {
                    ForEach(topic.tags.prefix(3)) { tag in
                        TagBadge(name: tag.name)
                    }
                }
            }
        }
    }

    // MARK: - Excerpt Row

    private var excerptRow: some View {
        Group {
            if let excerpt = topic.excerpt?.strippingDiscourseMarkup(), !excerpt.isEmpty {
                Text(excerpt)
                    .font(DesignTypography.serifCaption).foregroundStyle(.tertiary)
                    .lineLimit(2)
            }
        }
    }

    // MARK: - Bottom Stats Row (like count + views + time)

    private var bottomStatsRow: some View {
        HStack(spacing: 12) {
            if topic.likeCount > 0 {
                Label("\(topic.likeCount)", systemImage: "heart.fill")
                    .font(DesignTypography.serifCaption2).foregroundStyle(.pink.opacity(0.7))
            }
            if topic.views > 0 {
                Label("\(topic.views)", systemImage: "eye")
                    .font(DesignTypography.serifCaption2).foregroundStyle(.tertiary)
            }
            if topic.postsCount > 1 {
                Label("\(topic.postsCount - 1)", systemImage: "bubble.left")
                    .font(DesignTypography.serifCaption2).foregroundStyle(.tertiary)
            }

            Spacer()

            if let t = topic.lastPostedAt {
                Text(TimeUtils.relative(from: t))
                    .font(DesignTypography.serifCaption2).foregroundStyle(.quaternary)
            }
        }
    }
}

