//
//  HTTPClient.swift
//  LinuxDo
//
//  统一 HTTP 客户端 — @MainActor class
//

import Foundation

@MainActor
final class HTTPClient {
    static let shared = HTTPClient()
    let session: URLSession
    let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.httpShouldSetCookies = true
        session = URLSession(configuration: config)
        decoder = JSONDecoder()
        encoder = JSONEncoder()
    }

    // MARK: - Public API

    func get<T: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> T {
        var url = AppConstants.baseURL.appendingPathComponent(path)
        if !query.isEmpty {
            var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            comps.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
            if let u = comps.url { url = u }
        }
        var req = URLRequest(url: url)
        applyCommonHeaders(to: &req)
        req.httpMethod = "GET"
        return try await perform(req)
    }

    func getRawData(_ path: String, query: [String: String]? = nil) async throws -> Data {
        var url = AppConstants.baseURL.appendingPathComponent(path)
        if let query, !query.isEmpty {
            var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            comps.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
            if let u = comps.url { url = u }
        }
        var req = URLRequest(url: url)
        applyCommonHeaders(to: &req)
        req.httpMethod = "GET"
        try await injectCSRF(&req)
        let (data, resp) = try await session.data(for: req)
        guard let httpResp = resp as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }
        if httpResp.statusCode == 401 || httpResp.statusCode == 403 {
            let body = String(data: data, encoding: .utf8) ?? ""
            if body.contains("BAD CSRF") {
                let refreshed = try? await CSRFManager.shared.refresh()
                if let newToken = refreshed {
                    var retryReq = req
                    retryReq.setValue(newToken, forHTTPHeaderField: AppConstants.csrfTokenHeader)
                    let (retryData, retryResp) = try await session.data(for: retryReq)
                    if let retryHTTP = retryResp as? HTTPURLResponse, (200...299).contains(retryHTTP.statusCode) {
                        return retryData
                    }
                }
            }
            if httpResp.statusCode == 401 {
                SessionStore.shared.logout()
            }
            throw APIError.notLoggedIn
        }
        if !(200...299).contains(httpResp.statusCode) {
            throw APIError.httpError(httpResp.statusCode)
        }
        return data
    }

    func post<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        var req = URLRequest(url: AppConstants.baseURL.appendingPathComponent(path))
        req.httpMethod = "POST"
        applyCommonHeaders(to: &req)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try encoder.encode(body)
        try await injectCSRF(&req)
        return try await perform(req)
    }

    /// POST form-urlencoded — Discourse API 要求大多数写操作使用此格式
    func postForm<T: Decodable>(_ path: String, params: [String: String]) async throws -> T {
        var req = URLRequest(url: AppConstants.baseURL.appendingPathComponent(path))
        req.httpMethod = "POST"
        applyCommonHeaders(to: &req)
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = formBody(params.map { ($0.key, $0.value) })
        try await injectCSRF(&req)
        return try await perform(req)
    }

    /// PUT form-urlencoded
    func putForm<T: Decodable>(_ path: String, params: [String: String]) async throws -> T {
        try await putForm(path, params: params.map { ($0.key, $0.value) })
    }

    /// PUT form-urlencoded with repeated keys.
    func putForm<T: Decodable>(_ path: String, params: [(String, String)]) async throws -> T {
        var req = URLRequest(url: AppConstants.baseURL.appendingPathComponent(path))
        req.httpMethod = "PUT"
        applyCommonHeaders(to: &req)
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = formBody(params)
        try await injectCSRF(&req)
        return try await perform(req)
    }

    /// DELETE form-urlencoded body — used by Discourse poll vote removal.
    func deleteForm<T: Decodable>(_ path: String, params: [(String, String)]) async throws -> T {
        var req = URLRequest(url: AppConstants.baseURL.appendingPathComponent(path))
        req.httpMethod = "DELETE"
        applyCommonHeaders(to: &req)
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = formBody(params)
        try await injectCSRF(&req)
        return try await perform(req)
    }

    /// DELETE with query parameters — Discourse unlike/删除书签等需要
    func delete<T: Decodable>(_ path: String, query: [String: String]) async throws -> T {
        var url = AppConstants.baseURL.appendingPathComponent(path)
        if !query.isEmpty {
            var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            comps.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
            if let u = comps.url { url = u }
        }
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        applyCommonHeaders(to: &req)
        try await injectCSRF(&req)
        return try await perform(req)
    }

    func upload<T: Decodable>(_ path: String, multipart: MultipartFormData) async throws -> T {
        var req = URLRequest(url: AppConstants.baseURL.appendingPathComponent(path))
        req.httpMethod = "POST"
        applyCommonHeaders(to: &req)
        let boundary = "Boundary-\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.httpBody = multipart.encode(boundary: boundary)
        try await injectCSRF(&req)
        return try await perform(req)
    }

    func put<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        var req = URLRequest(url: AppConstants.baseURL.appendingPathComponent(path))
        req.httpMethod = "PUT"
        applyCommonHeaders(to: &req)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try encoder.encode(body)
        try await injectCSRF(&req)
        return try await perform(req)
    }

    func delete<T: Decodable>(_ path: String) async throws -> T {
        var req = URLRequest(url: AppConstants.baseURL.appendingPathComponent(path))
        req.httpMethod = "DELETE"
        applyCommonHeaders(to: &req)
        try await injectCSRF(&req)
        return try await perform(req)
    }

    func deleteVoid(_ path: String) async throws {
        var req = URLRequest(url: AppConstants.baseURL.appendingPathComponent(path))
        req.httpMethod = "DELETE"
        applyCommonHeaders(to: &req)
        try await injectCSRF(&req)
        struct Empty: Decodable {}
        let _: Empty = try await perform(req)
    }

    func putVoid(_ path: String, body: [String: Any]? = nil) async throws {
        var req = URLRequest(url: AppConstants.baseURL.appendingPathComponent(path))
        req.httpMethod = "PUT"
        applyCommonHeaders(to: &req)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body {
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        try await injectCSRF(&req)
        struct Empty: Decodable {}
        let _: Empty = try await perform(req)
    }

    // MARK: - Private

    private func applyCommonHeaders(to req: inout URLRequest) {
        req.setValue(AppConstants.userAgent, forHTTPHeaderField: "User-Agent")
        req.setValue(AppConstants.baseURL.absoluteString, forHTTPHeaderField: "Origin")
        req.setValue(AppConstants.requestedWithValue, forHTTPHeaderField: AppConstants.requestedWithHeader)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(AppConstants.baseURL.absoluteString + "/", forHTTPHeaderField: "Referer")
        req.setValue("empty", forHTTPHeaderField: "Sec-Fetch-Dest")
        req.setValue("cors", forHTTPHeaderField: "Sec-Fetch-Mode")
        req.setValue("same-origin", forHTTPHeaderField: "Sec-Fetch-Site")
    }

    private func injectCSRF(_ req: inout URLRequest) async throws {
        let token = try await CSRFManager.shared.getToken()
        req.setValue(token, forHTTPHeaderField: AppConstants.csrfTokenHeader)
    }

    private func perform<T: Decodable>(_ req: URLRequest) async throws -> T {
        let (data, resp) = try await session.data(for: req)

        guard let httpResp = resp as? HTTPURLResponse else {
            throw APIError.requestFailed(0, "非 HTTP 响应")
        }

        if let newToken = httpResp.value(forHTTPHeaderField: AppConstants.csrfTokenHeader) {
            await CSRFManager.shared.store(newToken)
        }

        if httpResp.statusCode == 401 || httpResp.statusCode == 403 {
            let body = String(data: data, encoding: .utf8) ?? ""
            let isBadCSRF = body.contains("BAD CSRF")

            if isBadCSRF {
                let refreshed = try? await CSRFManager.shared.refresh()
                if let newToken = refreshed {
                    var retryReq = req
                    retryReq.setValue(newToken, forHTTPHeaderField: AppConstants.csrfTokenHeader)
                    let (retryData, retryResp) = try await session.data(for: retryReq)
                    if let retryHTTP = retryResp as? HTTPURLResponse, (200...299).contains(retryHTTP.statusCode) {
                        return try decoder.decode(T.self, from: retryData)
                    }
                }
            }

            if httpResp.statusCode == 401 {
                SessionStore.shared.logout()
            }
            throw APIError.notLoggedIn
        }

        guard (200...299).contains(httpResp.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            throw APIError.requestFailed(httpResp.statusCode, body)
        }

        return try decoder.decode(T.self, from: data)
    }

    private func formBody(_ params: [(String, String)]) -> Data? {
        params
            .map { "\($0.0.formEncoded)=\($0.1.formEncoded)" }
            .joined(separator: "&")
            .data(using: .utf8)
    }
}

struct MultipartFormData {
    struct Part {
        let name: String
        let filename: String?
        let mimeType: String?
        let data: Data
    }

    let parts: [Part]

    func encode(boundary: String) -> Data {
        var body = Data()
        let lineBreak = "\r\n".data(using: .utf8)!
        let prefix = "--\(boundary)\r\n".data(using: .utf8)!

        for part in parts {
            body.append(prefix)
            var d = "Content-Disposition: form-data; name=\"\(part.name)\""
            if let fn = part.filename { d += "; filename=\"\(fn)\"" }
            body.append((d + "\r\n").data(using: .utf8)!)
            if let m = part.mimeType {
                body.append(("Content-Type: \(m)\r\n").data(using: .utf8)!)
            }
            body.append(lineBreak)
            body.append(part.data)
            body.append(lineBreak)
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return body
    }
}

private extension String {
    var formEncoded: String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=?/#[]@!$'()*,:;")
        return addingPercentEncoding(withAllowedCharacters: allowed) ?? self
    }
}
