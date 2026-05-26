//
//  CategoryService.swift
//  LinuxDo
//
//  分类列表 API
//

import Foundation

struct CategoryService {

    /// 获取全部分类
    static func list() async throws -> CategoryListResponse {
        try await HTTPClient.shared.get("categories.json")
    }
}
