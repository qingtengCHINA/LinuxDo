//
//  Topic.swift
//  LinuxDo
//
//  话题、帖子、标签、投票等核心数据模型
//

import Foundation

// MARK: - Tag

struct Tag: Codable, Identifiable, Hashable {
    let id: Int?
    let name: String
    let slug: String?

    init(from decoder: Decoder) throws {
        // 兼容字符串和对象两种格式
        let container = try decoder.singleValueContainer()
        if let nameStr = try? container.decode(String.self) {
            self.id = nil
            self.name = nameStr
            self.slug = nil
        } else {
            let obj = try decoder.container(keyedBy: CodingKeys.self)
            self.id = try obj.decodeIfPresent(Int.self, forKey: .id)
            self.name = try obj.decodeIfPresent(String.self, forKey: .name) ?? ""
            self.slug = try obj.decodeIfPresent(String.self, forKey: .slug)
        }
    }
}

// MARK: - Topic

struct Topic: Codable, Identifiable {
    let id: Int
    let title: String
    let slug: String
    let postsCount: Int
    let replyCount: Int
    let views: Int
    let likeCount: Int
    let excerpt: String?
    let createdAt: Date?
    let lastPostedAt: Date?
    let lastPosterUsername: String?
    let categoryID: Int
    let pinned: Bool
    let visible: Bool
    let closed: Bool
    let archived: Bool
    let tags: [Tag]
    let posters: [TopicPoster]
    let unseen: Bool
    let unread: Int
    let newPosts: Int
    let lastReadPostNumber: Int?
    let highestPostNumber: Int
    let hasAcceptedAnswer: Bool
    let canHaveAnswer: Bool
    let fancyTitle: String?
    let bumpedAt: Date?
    let archetype: String
    let imageUrl: String?
    let pinnedGlobally: Bool

    var bookmarkID: Int?
    var bookmarkName: String?
    var bookmarkReminderAt: Date?
    var bookmarkedPostNumber: Int?

    var readableCategoryID: String { "\(categoryID)" }
    var isPrivateMessage: Bool { archetype == "private_message" }

    enum CodingKeys: String, CodingKey {
        case id, title, slug, excerpt, tags, visible, closed, archived
        case pinned, unseen, unread, views, posters
        case postsCount = "posts_count"
        case replyCount = "reply_count"
        case likeCount = "like_count"
        case createdAt = "created_at"
        case lastPostedAt = "last_posted_at"
        case lastPosterUsername = "last_poster_username"
        case categoryID = "category_id"
        case newPosts = "new_posts"
        case lastReadPostNumber = "last_read_post_number"
        case highestPostNumber = "highest_post_number"
        case hasAcceptedAnswer = "has_accepted_answer"
        case canHaveAnswer = "can_have_answer"
        case fancyTitle = "fancy_title"
        case bumpedAt = "bumped_at"
        case archetype
        case imageUrl = "image_url"
        case pinnedGlobally = "pinned_globally"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        slug = try c.decodeIfPresent(String.self, forKey: .slug) ?? ""
        postsCount = try c.decodeIfPresent(Int.self, forKey: .postsCount) ?? 0
        replyCount = try c.decodeIfPresent(Int.self, forKey: .replyCount) ?? 0
        views = try c.decodeIfPresent(Int.self, forKey: .views) ?? 0
        likeCount = try c.decodeIfPresent(Int.self, forKey: .likeCount) ?? 0
        excerpt = try c.decodeIfPresent(String.self, forKey: .excerpt)
        createdAt = TimeUtils.parseUTC(try c.decodeIfPresent(String.self, forKey: .createdAt))
        lastPostedAt = TimeUtils.parseUTC(try c.decodeIfPresent(String.self, forKey: .lastPostedAt))
        lastPosterUsername = try c.decodeIfPresent(String.self, forKey: .lastPosterUsername)
        categoryID = try c.decodeIfPresent(Int.self, forKey: .categoryID) ?? 0
        pinned = try c.decodeIfPresent(Bool.self, forKey: .pinned) ?? false
        visible = try c.decodeIfPresent(Bool.self, forKey: .visible) ?? true
        closed = try c.decodeIfPresent(Bool.self, forKey: .closed) ?? false
        archived = try c.decodeIfPresent(Bool.self, forKey: .archived) ?? false
        tags = try c.decodeIfPresent([Tag].self, forKey: .tags) ?? []
        posters = try c.decodeIfPresent([TopicPoster].self, forKey: .posters) ?? []
        unseen = try c.decodeIfPresent(Bool.self, forKey: .unseen) ?? false
        unread = try c.decodeIfPresent(Int.self, forKey: .unread) ?? 0
        newPosts = try c.decodeIfPresent(Int.self, forKey: .newPosts) ?? 0
        lastReadPostNumber = try c.decodeIfPresent(Int.self, forKey: .lastReadPostNumber)
        highestPostNumber = try c.decodeIfPresent(Int.self, forKey: .highestPostNumber) ?? 0
        hasAcceptedAnswer = try c.decodeIfPresent(Bool.self, forKey: .hasAcceptedAnswer) ?? false
        canHaveAnswer = try c.decodeIfPresent(Bool.self, forKey: .canHaveAnswer) ?? false
        fancyTitle = try c.decodeIfPresent(String.self, forKey: .fancyTitle)
        bumpedAt = TimeUtils.parseUTC(try c.decodeIfPresent(String.self, forKey: .bumpedAt))
        archetype = try c.decodeIfPresent(String.self, forKey: .archetype) ?? "regular"
        imageUrl = try c.decodeIfPresent(String.self, forKey: .imageUrl)
        pinnedGlobally = try c.decodeIfPresent(Bool.self, forKey: .pinnedGlobally) ?? false
    }
}

// MARK: - TopicPoster

struct TopicPoster: Codable, Identifiable {
    let userID: Int
    let description: String
    let extras: String?
    let user: TopicUser?

    var id: Int { userID }

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case description, extras, user
    }
}

// MARK: - TopicUser

struct TopicUser: Codable, Identifiable {
    let id: Int
    let username: String
    let avatarTemplate: String

    var avatarURL: URL? {
        URLHelper.avatarURL(template: avatarTemplate)
    }

    enum CodingKeys: String, CodingKey {
        case id, username
        case avatarTemplate = "avatar_template"
    }
}

// MARK: - Post

struct Post: Codable, Identifiable {
    let id: Int
    let name: String?
    let username: String
    let avatarTemplate: String
    let animatedAvatar: String?
    let cooked: String
    let postNumber: Int
    let postType: Int
    let updatedAt: Date?
    let createdAt: Date?
    let likeCount: Int
    let replyCount: Int
    let replyToPostNumber: Int?
    let replyToUser: ReplyToUser?
    let bookmarked: Bool
    let bookmarkableID: Int?
    let canEdit: Bool
    let canDelete: Bool
    let canRecover: Bool
    let read: Bool
    let acceptedAnswer: Bool
    let canAcceptAnswer: Bool
    let canUnacceptAnswer: Bool
    let deletedAt: Date?
    let userDeleted: Bool
    let userTitle: String?
    let flairURL: String?
    let flairName: String?
    let flairBgColor: String?
    let flairColor: String?
    let userID: Int?
    let moderator: Bool
    let admin: Bool
    let hidden: Bool
    let cookedHidden: Bool
    let canSeeHiddenPost: Bool
    let reactions: [PostReaction]?
    let currentUserReaction: PostReaction?
    let polls: [Poll]?
    let pollsVotes: [String: [String]]?
    let mentionedUsers: [MentionedUser]?

    var avatarURL: URL? {
        if let anim = animatedAvatar, !anim.isEmpty {
            return URLHelper.resolve(anim)
        }
        return URLHelper.avatarURL(template: avatarTemplate)
    }

    var isDeleted: Bool { deletedAt != nil }

    enum CodingKeys: String, CodingKey {
        case id, name, username, cooked, read, hidden
        case avatarTemplate = "avatar_template"
        case animatedAvatar = "animated_avatar"
        case postNumber = "post_number"
        case postType = "post_type"
        case updatedAt = "updated_at"
        case createdAt = "created_at"
        case likeCount = "like_count"
        case replyCount = "reply_count"
        case replyToPostNumber = "reply_to_post_number"
        case replyToUser = "reply_to_user"
        case bookmarked
        case bookmarkableID = "bookmarkable_id"
        case canEdit = "can_edit"
        case canDelete = "can_delete"
        case canRecover = "can_recover"
        case acceptedAnswer = "accepted_answer"
        case canAcceptAnswer = "can_accept_answer"
        case canUnacceptAnswer = "can_unaccept_answer"
        case deletedAt = "deleted_at"
        case userDeleted = "user_deleted"
        case userTitle = "user_title"
        case flairURL = "flair_url"
        case flairName = "flair_name"
        case flairBgColor = "flair_bg_color"
        case flairColor = "flair_color"
        case userID = "user_id"
        case moderator, admin
        case cookedHidden = "cooked_hidden"
        case canSeeHiddenPost = "can_see_hidden_post"
        case reactions
        case currentUserReaction = "current_user_reaction"
        case polls
        case pollsVotes = "polls_votes"
        case mentionedUsers = "mentioned_users"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        username = try c.decodeIfPresent(String.self, forKey: .username) ?? "Unknown"
        avatarTemplate = try c.decodeIfPresent(String.self, forKey: .avatarTemplate) ?? ""
        animatedAvatar = try c.decodeIfPresent(String.self, forKey: .animatedAvatar)
        cooked = try c.decodeIfPresent(String.self, forKey: .cooked) ?? ""
        postNumber = try c.decodeIfPresent(Int.self, forKey: .postNumber) ?? 0
        postType = try c.decodeIfPresent(Int.self, forKey: .postType) ?? 1
        updatedAt = TimeUtils.parseUTC(try c.decodeIfPresent(String.self, forKey: .updatedAt))
        createdAt = TimeUtils.parseUTC(try c.decodeIfPresent(String.self, forKey: .createdAt))
        likeCount = try c.decodeIfPresent(Int.self, forKey: .likeCount) ?? 0
        replyCount = try c.decodeIfPresent(Int.self, forKey: .replyCount) ?? 0
        replyToPostNumber = try c.decodeIfPresent(Int.self, forKey: .replyToPostNumber)
        replyToUser = try c.decodeIfPresent(ReplyToUser.self, forKey: .replyToUser)
        bookmarked = try c.decodeIfPresent(Bool.self, forKey: .bookmarked) ?? false
        bookmarkableID = try c.decodeIfPresent(Int.self, forKey: .bookmarkableID)
        canEdit = try c.decodeIfPresent(Bool.self, forKey: .canEdit) ?? false
        canDelete = try c.decodeIfPresent(Bool.self, forKey: .canDelete) ?? false
        canRecover = try c.decodeIfPresent(Bool.self, forKey: .canRecover) ?? false
        read = try c.decodeIfPresent(Bool.self, forKey: .read) ?? false
        acceptedAnswer = try c.decodeIfPresent(Bool.self, forKey: .acceptedAnswer) ?? false
        canAcceptAnswer = try c.decodeIfPresent(Bool.self, forKey: .canAcceptAnswer) ?? false
        canUnacceptAnswer = try c.decodeIfPresent(Bool.self, forKey: .canUnacceptAnswer) ?? false
        deletedAt = TimeUtils.parseUTC(try c.decodeIfPresent(String.self, forKey: .deletedAt))
        userDeleted = try c.decodeIfPresent(Bool.self, forKey: .userDeleted) ?? false
        userTitle = try c.decodeIfPresent(String.self, forKey: .userTitle)
        flairURL = try c.decodeIfPresent(String.self, forKey: .flairURL)
        flairName = try c.decodeIfPresent(String.self, forKey: .flairName)
        flairBgColor = try c.decodeIfPresent(String.self, forKey: .flairBgColor)
        flairColor = try c.decodeIfPresent(String.self, forKey: .flairColor)
        userID = try c.decodeIfPresent(Int.self, forKey: .userID)
        moderator = try c.decodeIfPresent(Bool.self, forKey: .moderator) ?? false
        admin = try c.decodeIfPresent(Bool.self, forKey: .admin) ?? false
        hidden = try c.decodeIfPresent(Bool.self, forKey: .hidden) ?? false
        cookedHidden = try c.decodeIfPresent(Bool.self, forKey: .cookedHidden) ?? false
        canSeeHiddenPost = try c.decodeIfPresent(Bool.self, forKey: .canSeeHiddenPost) ?? false
        reactions = try c.decodeIfPresent([PostReaction].self, forKey: .reactions)
        currentUserReaction = try c.decodeIfPresent(PostReaction.self, forKey: .currentUserReaction)
        polls = try c.decodeIfPresent([Poll].self, forKey: .polls)
        pollsVotes = try c.decodePollVotesIfPresent(forKey: .pollsVotes)
        mentionedUsers = try c.decodeIfPresent([MentionedUser].self, forKey: .mentionedUsers)
    }
}

// MARK: - Poll

struct Poll: Codable, Equatable {
    let id: Int?
    let name: String
    let type: String
    let status: String
    let results: String
    let options: [PollOption]
    let voters: Int
    let min: Int?
    let max: Int?

    var isMultiple: Bool { type == "multiple" }
    var isClosed: Bool { status == "closed" }

    enum CodingKeys: String, CodingKey {
        case id, name, type, status, results, options, voters, min, max
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "poll"
        type = try c.decodeIfPresent(String.self, forKey: .type) ?? "regular"
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? "open"
        results = try c.decodeIfPresent(String.self, forKey: .results) ?? "always"
        options = try c.decodeIfPresent([PollOption].self, forKey: .options) ?? []
        voters = try c.decodeIfPresent(Int.self, forKey: .voters) ?? 0
        min = try c.decodeIfPresent(Int.self, forKey: .min)
        max = try c.decodeIfPresent(Int.self, forKey: .max)
    }
}

struct PollOption: Codable, Identifiable, Equatable {
    let id: String
    let html: String
    let votes: Int

    enum CodingKeys: String, CodingKey {
        case id, html, votes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let stringID = try? c.decode(String.self, forKey: .id) {
            id = stringID
        } else if let intID = try? c.decode(Int.self, forKey: .id) {
            id = "\(intID)"
        } else {
            id = UUID().uuidString
        }
        html = try c.decodeIfPresent(String.self, forKey: .html) ?? ""
        votes = try c.decodeIfPresent(Int.self, forKey: .votes) ?? 0
    }
}

private extension KeyedDecodingContainer {
    func decodePollVotesIfPresent(forKey key: Key) throws -> [String: [String]]? {
        guard contains(key) else { return nil }
        let raw = try decode([String: [LosslessString]].self, forKey: key)
        return raw.mapValues { $0.map(\.value) }
    }
}

private struct LosslessString: Decodable {
    let value: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = "\(int)"
        } else {
            value = ""
        }
    }
}

// MARK: - PostReaction

struct PostReaction: Codable, Equatable {
    let id: String
    let type: String
    let count: Int

    enum CodingKeys: String, CodingKey {
        case id, type, count
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let stringID = try? c.decode(String.self, forKey: .id) {
            id = stringID
        } else if let intID = try? c.decode(Int.self, forKey: .id) {
            id = "\(intID)"
        } else {
            id = UUID().uuidString
        }
        type = try c.decodeIfPresent(String.self, forKey: .type) ?? ""
        count = try c.decodeIfPresent(Int.self, forKey: .count) ?? 0
    }
}

// MARK: - ReplyToUser

struct ReplyToUser: Codable {
    let username: String
    let name: String?
    let avatarTemplate: String

    enum CodingKeys: String, CodingKey {
        case username, name
        case avatarTemplate = "avatar_template"
    }
}

// MARK: - MentionedUser

struct MentionedUser: Codable, Identifiable {
    let id: Int
    let username: String
    let name: String?
    let avatarTemplate: String?

    enum CodingKeys: String, CodingKey {
        case id, username, name
        case avatarTemplate = "avatar_template"
    }
}

// MARK: - PostStream

struct PostStream: Codable {
    var posts: [Post]
    let stream: [Int]
    let gaps: [String: [Int]]?
}

// MARK: - TopicDetail

struct TopicDetail: Codable, Identifiable {
    let id: Int
    let title: String
    let slug: String
    let postsCount: Int
    var postStream: PostStream
    let categoryID: Int
    let closed: Bool
    let archived: Bool
    let tags: [Tag]?
    let views: Int
    let likeCount: Int
    let createdAt: Date?
    let visible: Bool
    let lastReadPostNumber: Int?
    let archetype: String
    let bookmarked: Bool
    let bookmarkableID: Int?

    var isPrivateMessage: Bool { archetype == "private_message" }

    enum CodingKeys: String, CodingKey {
        case id, title, slug, tags, views, closed, archived, visible, archetype
        case postsCount = "posts_count"
        case postStream = "post_stream"
        case categoryID = "category_id"
        case likeCount = "like_count"
        case createdAt = "created_at"
        case lastReadPostNumber = "last_read_post_number"
        case bookmarked = "bookmarked"
        case bookmarkableID = "bookmarkable_id"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        slug = try c.decodeIfPresent(String.self, forKey: .slug) ?? ""
        postsCount = try c.decodeIfPresent(Int.self, forKey: .postsCount) ?? 0
        postStream = try c.decode(PostStream.self, forKey: .postStream)
        categoryID = try c.decodeIfPresent(Int.self, forKey: .categoryID) ?? 0
        closed = try c.decodeIfPresent(Bool.self, forKey: .closed) ?? false
        archived = try c.decodeIfPresent(Bool.self, forKey: .archived) ?? false
        tags = try c.decodeIfPresent([Tag].self, forKey: .tags)
        views = try c.decodeIfPresent(Int.self, forKey: .views) ?? 0
        likeCount = try c.decodeIfPresent(Int.self, forKey: .likeCount) ?? 0
        createdAt = TimeUtils.parseUTC(try c.decodeIfPresent(String.self, forKey: .createdAt))
        visible = try c.decodeIfPresent(Bool.self, forKey: .visible) ?? true
        lastReadPostNumber = try c.decodeIfPresent(Int.self, forKey: .lastReadPostNumber)
        archetype = try c.decodeIfPresent(String.self, forKey: .archetype) ?? "regular"
        bookmarked = try c.decodeIfPresent(Bool.self, forKey: .bookmarked) ?? false
        bookmarkableID = try c.decodeIfPresent(Int.self, forKey: .bookmarkableID)
    }
}

