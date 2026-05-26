//
//  Constants.swift
//  LinuxDo
//
//  Discourse API 常量与配置
//  使用 struct + static let computes 避免 Swift 6 @MainActor 隔离冲突
//

import Foundation

struct AppConstants {
    private init() {}

    /// linux.do 论坛域名
    nonisolated(unsafe) static let baseURL = URL(string: "https://linux.do")!

    nonisolated(unsafe) static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        + "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"

    nonisolated(unsafe) static let sessionCookieName = "_t"
    nonisolated(unsafe) static let csrfEndpoint = "/session/csrf"
    nonisolated(unsafe) static let currentUserEndpoint = "/session/current.json"
    nonisolated(unsafe) static let csrfTokenHeader = "X-CSRF-Token"
    nonisolated(unsafe) static let requestedWithHeader = "X-Requested-With"
    nonisolated(unsafe) static let requestedWithValue = "XMLHttpRequest"

    nonisolated(unsafe) static let keychainService = "com.linuxdo.session"
    nonisolated(unsafe) static let keychainCSRFTokenKey = "csrf_token"
    nonisolated(unsafe) static let keychainCookiesKey = "session_cookies"
    nonisolated(unsafe) static let keychainUsernameKey = "current_username"

    nonisolated(unsafe) static let imageCacheDiskLimit = 100 * 1024 * 1024
    nonisolated(unsafe) static let imageCacheMemoryLimit = 50 * 1024 * 1024
    nonisolated(unsafe) static let imageCacheExpiration: TimeInterval = 7 * 24 * 3600
    nonisolated(unsafe) static let defaultPageSize = 30
}
