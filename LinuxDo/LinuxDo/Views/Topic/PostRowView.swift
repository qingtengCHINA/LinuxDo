//
//  PostRowView.swift
//  LinuxDo
//

import SwiftUI

struct PostRowView: View {
    let post: Post
    let isOriginalPost: Bool
    @AppStorage("fontSizeScale") private var fontSizeScale = 1.0
    @State private var contentHeight: CGFloat = 20
    var onReply: (() -> Void)?
    var onLike: (() -> Void)?
    var onBookmark: (() -> Void)?
    var onShare: (() -> Void)?
    var onImageTap: ((String) -> Void)?
    var onEdit: (() -> Void)?
    var onLinkTap: ((URL) -> Void)?

    private var baseFontSize: CGFloat { 15 * fontSizeScale }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            postHeader
            replyToIndicator
            postContent
            acceptedAnswerBanner
            postActionBar
        }
        .padding(.vertical, 12).padding(.horizontal, 12)
        .background(isOriginalPost ? Color(.secondarySystemGroupedBackground) : Color(.systemBackground))
    }

    // MARK: - Post Header (avatar + name + badges + time + post#)

    private var postHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            AvatarView(url: post.avatarURL, size: 40)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(post.name ?? post.username)
                        .font(DesignTypography.serifSubheadline).fontWeight(.semibold)
                        .lineLimit(1)

                    if post.admin { roleBadge("管理", .red) }
                    if post.moderator { roleBadge("版主", .purple) }

                    if let flair = post.flairName, !flair.isEmpty {
                        flairBadge(flair, bgColor: post.flairBgColor, fgColor: post.flairColor)
                    }
                }

                HStack(spacing: 4) {
                    if let title = post.userTitle, !title.isEmpty {
                        Text(title)
                            .font(DesignTypography.serifCaption2).foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            if let d = post.createdAt {
                Text(TimeUtils.detail(from: d))
                    .font(DesignTypography.serifCaption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Reply-To Indicator

    private var replyToIndicator: some View {
        Group {
            if let replyTo = post.replyToUser {
                HStack(spacing: 4) {
                    Image(systemName: "arrowshape.turn.up.left")
                        .font(DesignTypography.serifCaption2).foregroundStyle(.secondary)
                    Text(replyTo.username)
                        .font(DesignTypography.serifCaption2).foregroundStyle(.secondary)
                    if let name = replyTo.name {
                        Text("· \(name)")
                            .font(DesignTypography.serifCaption2).foregroundStyle(.tertiary)
                    }
                }
                .padding(.leading, 4)
            }
        }
    }

    // MARK: - Post Content

    private var postContent: some View {
        Group {
            if post.cookedHidden {
                collapsedContent("此帖已被隐藏，点击查看")
            } else if post.isDeleted {
                collapsedContent("此帖已被删除")
            } else {
                DiscourseWebView(
                    html: post.cooked,
                    baseFontSize: baseFontSize,
                    onImageTap: { url in onImageTap?(url) },
                    onLinkTap: { url in onLinkTap?(url) },
                    contentHeight: $contentHeight
                )
                .frame(height: max(contentHeight, 20))
            }
        }
    }

    private func collapsedContent(_ text: String) -> some View {
        Text(text).italic().foregroundStyle(.secondary)
            .padding(.vertical, 8).padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Accepted Answer Banner

    private var acceptedAnswerBanner: some View {
        Group {
            if post.acceptedAnswer {
                Label("✓ 已接受答案", systemImage: "checkmark.seal.fill")
                    .font(DesignTypography.serifCaption).foregroundStyle(.green)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
    }

    // MARK: - Post Action Bar

    private var postActionBar: some View {
        HStack(spacing: 16) {
            likeButton
            replyButton
            bookmarkButton
            shareButton
            if post.canEdit { editButton }

            Spacer()

            if !post.read {
                Text("新")
                    .font(DesignTypography.serifCaption2).foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(Color.accentColor))
            }

            Text("#\(post.postNumber)")
                .font(DesignTypography.serifCaption2).foregroundStyle(.quaternary)
        }
        .padding(.top, 4)
    }

    private var likeButton: some View {
        Button { onLike?() } label: {
            HStack(spacing: 3) {
                Image(systemName: post.currentUserReaction != nil ? "heart.fill" : "heart")
                if post.likeCount > 0 { Text("\(post.likeCount)") }
            }
            .font(DesignTypography.serifCaption)
            .foregroundStyle(post.currentUserReaction != nil ? .red : .secondary)
        }
        .buttonStyle(.plain)
    }

    private var replyButton: some View {
        Button { onReply?() } label: {
            HStack(spacing: 3) {
                Image(systemName: "arrowshape.turn.up.left")
                if post.replyCount > 0 { Text("\(post.replyCount)") }
            }
            .font(DesignTypography.serifCaption).foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }

    private var bookmarkButton: some View {
        Button { onBookmark?() } label: {
            Image(systemName: post.bookmarked ? "bookmark.fill" : "bookmark")
                .font(DesignTypography.serifCaption)
                .foregroundStyle(post.bookmarked ? .orange : .secondary)
        }
        .buttonStyle(.plain)
    }

    private var shareButton: some View {
        Button { onShare?() } label: {
            Image(systemName: "square.and.arrow.up")
                .font(DesignTypography.serifCaption).foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }

    private var editButton: some View {
        Button { onEdit?() } label: {
            Image(systemName: "pencil")
                .font(DesignTypography.serifCaption).foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Badge Helpers

    private func roleBadge(_ text: String, _ color: Color) -> some View {
        Text(text).font(DesignTypography.serifCaption2).fontWeight(.medium)
            .padding(.horizontal, 4).padding(.vertical, 1)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    private func flairBadge(_ name: String, bgColor: String?, fgColor: String?) -> some View {
        let bg = Color(hex: bgColor ?? "0088CC") ?? .blue
        let fg = Color(hex: fgColor ?? "FFFFFF") ?? .white
        return Text(name).font(DesignTypography.serifCaption2).fontWeight(.medium)
            .padding(.horizontal, 4).padding(.vertical, 1)
            .foregroundStyle(fg)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}
