//
//  DraftService.swift
//  LinuxDo
//

import Foundation

struct Draft: Codable, Identifiable {
    let id: Int
    let topicID: Int?
    let title: String?
    let excerpt: String?
    let createdAt: Date?
    let updatedAt: Date?
    let key: String?
    let sequence: Int?
    let owner: String?
    let data: String?

    enum CodingKeys: String, CodingKey {
        case id, title, excerpt, key, sequence, owner, data
        case topicID = "topic_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id) ?? 0
        topicID = try c.decodeIfPresent(Int.self, forKey: .topicID)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        excerpt = try c.decodeIfPresent(String.self, forKey: .excerpt)
        key = try c.decodeIfPresent(String.self, forKey: .key)
        sequence = try c.decodeIfPresent(Int.self, forKey: .sequence)
        owner = try c.decodeIfPresent(String.self, forKey: .owner)
        data = try c.decodeIfPresent(String.self, forKey: .data)
        createdAt = TimeUtils.parseUTC(try c.decodeIfPresent(String.self, forKey: .createdAt))
        updatedAt = TimeUtils.parseUTC(try c.decodeIfPresent(String.self, forKey: .updatedAt))
    }
}

@MainActor
struct DraftService {
    static func list() async throws -> [Draft] {
        struct Response: Decodable {
            let drafts: [Draft]
        }
        let resp: Response = try await HTTPClient.shared.get("drafts.json")
        return resp.drafts
    }
}