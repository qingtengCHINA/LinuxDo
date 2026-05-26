//
//  CookieBridge.swift
//  LinuxDo
//
//  WKHTTPCookieStore ↔ HTTPCookieStorage 双向桥接
//  @MainActor 以适配 WKWebsiteDataStore 的 MainActor 隔离要求
//

import Foundation
import WebKit

@MainActor
final class CookieBridge {
    static let shared = CookieBridge()
    private init() {}

    func syncFromWebView(dataStore: WKWebsiteDataStore = .default()) async -> [HTTPCookie] {
        let cookieStore = dataStore.httpCookieStore
        let allCookies = await cookieStore.allCookies()
        let targetCookies = allCookies.filter { $0.domain.contains("linux.do") }

        for cookie in targetCookies {
            HTTPCookieStorage.shared.setCookie(cookie)
        }

        return targetCookies
    }

    func syncToWebView(dataStore: WKWebsiteDataStore = .default()) async {
        let cookieStore = dataStore.httpCookieStore
        guard let cookies = HTTPCookieStorage.shared.cookies(for: AppConstants.baseURL) else { return }
        for cookie in cookies {
            await cookieStore.setCookie(cookie)
        }
    }

    func clearWebViewCookies(dataStore: WKWebsiteDataStore = .default()) async {
        let cookieStore = dataStore.httpCookieStore
        let allCookies = await cookieStore.allCookies()
        for cookie in allCookies where cookie.domain.contains("linux.do") {
            await cookieStore.delete(cookie)
        }
    }
}

extension WKHTTPCookieStore {
    func allCookies() async -> [HTTPCookie] {
        await withCheckedContinuation { c in
            getAllCookies { cookies in c.resume(returning: cookies) }
        }
    }

    func setCookie(_ cookie: HTTPCookie) async {
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            setCookie(cookie) { c.resume() }
        }
    }

    func delete(_ cookie: HTTPCookie) async {
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            delete(cookie) { c.resume() }
        }
    }
}
