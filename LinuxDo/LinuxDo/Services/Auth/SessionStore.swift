//
//  SessionStore.swift
//  LinuxDo
//
//  Keychain 凭证 + HTTPCookie 持久化
//  管理 _t session cookie、CSRF token、当前用户名
//

import Foundation
import Security

@Observable
final class SessionStore {
    static let shared = SessionStore()

    private(set) var csrfToken: String?
    private(set) var username: String?
    private(set) var isLoggedIn: Bool = false {
        didSet { if !isLoggedIn { clearCache() } }
    }

    private var sessionCookie: HTTPCookie?

    // MARK: - Public

    /// 登录完成后调用：持久化 cookie + CSRF + username
    func persistLogin(cookies: [HTTPCookie], csrf: String, username: String) {
        self.csrfToken = csrf
        self.username = username
        self.isLoggedIn = true

        if let _t = cookies.first(where: { $0.name == AppConstants.sessionCookieName }) {
            self.sessionCookie = _t
            saveCookie(_t)
        }
        save(key: AppConstants.keychainCSRFTokenKey, value: csrf)
        save(key: AppConstants.keychainUsernameKey, value: username)

        // 双向桥接：写入 HTTPCookieStorage 供 URLSession 后续请求使用
        if let cookie = cookies.first(where: { $0.name == AppConstants.sessionCookieName }) {
            HTTPCookieStorage.shared.setCookie(cookie)
        }
    }

    /// 从 Keychain 恢复会话（应用冷启动时调用）
    func restoreFromKeychain() -> Bool {
        csrfToken = read(AppConstants.keychainCSRFTokenKey)
        username = read(AppConstants.keychainUsernameKey)

        guard csrfToken != nil, username != nil else {
            isLoggedIn = false
            return false
        }

        // 恢复 _t cookie 到 URLSession 共享存储
        if let cookie = restoreCookie() {
            HTTPCookieStorage.shared.setCookie(cookie)
            sessionCookie = cookie
        }

        isLoggedIn = true
        return true
    }

    /// 登出：清除 Keychain + HTTPCookieStorage
    func logout() {
        csrfToken = nil
        username = nil
        isLoggedIn = false

        // 清除 Keychain
        delete(AppConstants.keychainCSRFTokenKey)
        delete(AppConstants.keychainUsernameKey)
        delete(AppConstants.keychainCookiesKey)

        // 清除 HTTPCookieStorage 中的 linux.do cookie
        if let cs = HTTPCookieStorage.shared.cookies(for: AppConstants.baseURL) {
            for c in cs { HTTPCookieStorage.shared.deleteCookie(c) }
        }
        if let cs = HTTPCookieStorage.shared.cookies {
            for c in cs where c.domain.contains("linux.do") {
                HTTPCookieStorage.shared.deleteCookie(c)
            }
        }
    }

    /// 更新 CSRF token（响应头中返回新的时调用）
    func updateCSRFToken(_ token: String) {
        csrfToken = token
        save(key: AppConstants.keychainCSRFTokenKey, value: token)
    }

    /// 清除 CSRF token（刷新时调用，强制从服务器重新获取）
    func clearCSRFToken() {
        csrfToken = nil
        delete(AppConstants.keychainCSRFTokenKey)
    }

    /// 所有 linux.do 域名的 cookies（用于请求头注入）
    var activeCookies: [HTTPCookie] {
        HTTPCookieStorage.shared.cookies(for: AppConstants.baseURL) ?? []
    }

    // MARK: - Keychain

    private func save(key: String, value: String) {
        delete(key)
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: AppConstants.keychainService,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private func read(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: AppConstants.keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: AppConstants.keychainService,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Cookie Storage

    private func saveCookie(_ cookie: HTTPCookie) {
        let props = cookie.properties ?? [:]
        let data = try? NSKeyedArchiver.archivedData(withRootObject: props, requiringSecureCoding: false)
        guard let data else { return }
        delete(AppConstants.keychainCookiesKey)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: AppConstants.keychainService,
            kSecAttrAccount as String: AppConstants.keychainCookiesKey,
            kSecValueData as String: data,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private func restoreCookie() -> HTTPCookie? {
        guard let data = read(AppConstants.keychainCookiesKey)?.data(using: .utf8) else {
            // 尝试从 Keychain 二进值读
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: AppConstants.keychainService,
                kSecAttrAccount as String: AppConstants.keychainCookiesKey,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne,
            ]
            var result: AnyObject?
            guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
                  let binary = result as? Data,
                  let props = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSDictionary.self, from: binary) as? [HTTPCookiePropertyKey: Any]
            else { return nil }
            return HTTPCookie(properties: props)
        }
        guard let props = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSDictionary.self, from: data) as? [HTTPCookiePropertyKey: Any]
        else { return nil }
        return HTTPCookie(properties: props)
    }

    private func clearCache() {
        sessionCookie = nil
    }
}
