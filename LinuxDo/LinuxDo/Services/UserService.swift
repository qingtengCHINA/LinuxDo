//
//  UserService.swift
//  LinuxDo
//

import Foundation

@MainActor final class UserService {
    static let shared = UserService()
    private init() {}

    func currentUser() async throws -> CurrentUserResponse {
        try await HTTPClient.shared.get(AppConstants.currentUserEndpoint)
    }

    func summary(username: String) async throws -> UserSummary {
        let resp: [String: UserSummary] = try await HTTPClient.shared.get("u/\(username)/summary.json")
        if let summary = resp["user_summary"] {
            return summary
        }
        throw APIError.decodingFailed("user_summary 字段缺失")
    }

    func profile(username: String) async throws -> User {
        struct Response: Decodable { let user: User }
        let resp: Response = try await HTTPClient.shared.get("u/\(username).json")
        return resp.user
    }

    func badges(username: String) async throws -> UserBadgeResponse {
        try await HTTPClient.shared.get("user-badges/\(username).json")
    }

    func toggleFollow(username: String, isFollowing: Bool) async throws {
        if isFollowing {
            try await HTTPClient.shared.putVoid("follow/\(username).json")
        } else {
            try await HTTPClient.shared.deleteVoid("follow/\(username).json")
        }
    }

    func userTopics(username: String, page: Int = 0) async throws -> TopicListResponse {
        try await HTTPClient.shared.get("topics/created-by/\(username).json", query: ["page": "\(page)"])
    }
}