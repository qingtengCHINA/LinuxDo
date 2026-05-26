//
//  CSRFManager.swift
//  LinuxDo
//
//  CSRF Token 管理 — @MainActor class
//

import Foundation

@MainActor
final class CSRFManager {
    static let shared = CSRFManager()
    private var cachedToken: String?

    private init() {}

    func getToken() async throws -> String {
        if let stored = SessionStore.shared.csrfToken {
            cachedToken = stored
            return stored
        }
        if let cached = cachedToken { return cached }

        return try await fetchFromServerThenStore()
    }

    private func fetchFromServerThenStore() async throws -> String {
        let token = try await fetchFromServer()
        store(token)
        return token
    }

    func refresh() async throws -> String {
        cachedToken = nil
        SessionStore.shared.clearCSRFToken()
        return try await fetchFromServerThenStore()
    }

    func store(_ token: String) {
        cachedToken = token
        SessionStore.shared.updateCSRFToken(token)
    }

    func clear() {
        cachedToken = nil
    }

    private func fetchFromServer() async throws -> String {
        let session = HTTPClient.shared.session
        var req = URLRequest(url: AppConstants.baseURL.appendingPathComponent(AppConstants.csrfEndpoint))
        req.setValue(AppConstants.userAgent, forHTTPHeaderField: "User-Agent")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(AppConstants.baseURL.absoluteString, forHTTPHeaderField: "Origin")
        req.setValue(AppConstants.baseURL.absoluteString + "/", forHTTPHeaderField: "Referer")

        let (data, resp) = try await session.data(for: req)
        guard let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200 else {
            throw APIError.csrfFetchFailed
        }
        if let newToken = httpResp.value(forHTTPHeaderField: AppConstants.csrfTokenHeader) {
            store(newToken)
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let token = json?["csrf"] as? String, !token.isEmpty else {
            throw APIError.csrfTokenMissing
        }
        return token
    }
}

enum APIError: Error, LocalizedError {
    case csrfFetchFailed
    case csrfTokenMissing
    case notLoggedIn
    case requestFailed(Int, String?)
    case decodingFailed(String)
    case httpError(Int)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .csrfFetchFailed: "CSRF token 获取失败"
        case .csrfTokenMissing: "响应中没有 CSRF token"
        case .notLoggedIn: "未登录"
        case .requestFailed(let code, let msg): "请求失败 (\(code)): \(msg ?? "")"
        case .decodingFailed(let detail): "解析失败: \(detail)"
        case .httpError(let code): "HTTP 错误 (\(code))"
        case .networkError(let err): "网络错误: \(err.localizedDescription)"
        }
    }
}
