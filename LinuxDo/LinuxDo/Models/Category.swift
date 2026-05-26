//
//  Category.swift
//  LinuxDo
//
//  分类数据模型
//

import Foundation

struct DiscourseCategory: Codable, Identifiable {
    let id: Int
    let name: String
    let color: String
    let textColor: String?
    let slug: String
    let topicCount: Int
    let postCount: Int
    let position: Int
    let descriptionText: String?
    let descriptionExcerpt: String?
    let parentCategoryID: Int?
    let subcategoryIDs: [Int]?
    let hasChildren: Bool
    let readRestricted: Bool

    /// 十六进制颜色 → SwiftUI Color 兼容格式
    var hexColor: String { color.hasPrefix("#") ? color : "#\(color)" }

    enum CodingKeys: String, CodingKey {
        case id, name, color, slug, position
        case textColor = "text_color"
        case topicCount = "topic_count"
        case postCount = "post_count"
        case descriptionText = "description_text"
        case descriptionExcerpt = "description_excerpt"
        case parentCategoryID = "parent_category_id"
        case subcategoryIDs = "subcategory_ids"
        case hasChildren = "has_children"
        case readRestricted = "read_restricted"
    }
}

struct CategoryListResponse: Codable {
    let categoryList: CategoryList

    enum CodingKeys: String, CodingKey {
        case categoryList = "category_list"
    }
}

struct CategoryList: Codable {
    let categories: [DiscourseCategory]
}
