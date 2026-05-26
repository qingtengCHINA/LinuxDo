//
//  URLHelper.swift
//  LinuxDo
//
//  URL 拼接与 CDN 路径解析
//  参考 fluxdo lib/utils/url_helper.dart
//

import Foundation

enum URLHelper {

    /// linux.do CDN 域名（static 资源走 CDN）
    private static let cdnHosts: Set<String> = [
        "cdn.linux.do",
        "uploads.linux.do",
    ]

    /// 解析相对路径或完整 URL，自动补全 baseURL
    /// - "/uploads/xxx" → "https://linux.do/uploads/xxx"
    /// - "https://cdn.linux.do/xxx" → 不变
    /// - "//cdn.linux.do/xxx" → "https://cdn.linux.do/xxx"
    static func resolve(_ path: String?) -> URL? {
        guard let path, !path.isEmpty else { return nil }

        // 已是完整 http(s) URL
        if let url = URL(string: path), url.scheme != nil {
            return url
        }

        // 协议相对 URL
        if path.hasPrefix("//") {
            return URL(string: "https:" + path)
        }

        // 相对路径 → 拼接 baseURL
        return URL(string: path, relativeTo: AppConstants.baseURL)?.absoluteURL
    }

    /// 头像 URL（替换 {size} 占位符）
    static func avatarURL(template: String, size: Int = 96) -> URL? {
        let replaced = template.replacingOccurrences(of: "{size}", with: "\(size)")
        return resolve(replaced)
    }
}
