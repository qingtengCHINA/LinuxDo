//
//  LoginView.swift
//  LinuxDo
//
//  WKWebView 登录页面
//  注入 JS 轮询脚本检测 <meta name="current-username"> + Discourse.User
//  对齐 fluxdo lib/pages/webview_login_page.dart 的检测逻辑
//

import SwiftUI
import WebKit

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var loginCompleted = false

    var onLoginSuccess: (() -> Void)?

    var body: some View {
        NavigationStack {
            LoginWebView(
                onLoginDetected: { cookies, csrf, username in
                    SessionStore.shared.persistLogin(cookies: cookies, csrf: csrf, username: username)
                    loginCompleted = true
                }
            )
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("登录 LinuxDo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .onChange(of: loginCompleted) { _, completed in
                if completed {
                    onLoginSuccess?()
                    dismiss()
                }
            }
        }
    }
}

// MARK: - JS Message Handler Name

private let messageHandlerName = "fluxdo"

// MARK: - WKWebView Representable

struct LoginWebView: UIViewRepresentable {
    let onLoginDetected: ([HTTPCookie], String, String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onLoginDetected: onLoginDetected)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        // 注册 JS → Swift 消息通道
        config.userContentController.add(context.coordinator, name: messageHandlerName)

        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs
        config.websiteDataStore = .nonPersistent()

        // 注入轮询脚本：每 500ms 检测登录状态，匹配后发消息给 Swift
        let script = WKUserScript(
            source: """
            (function() {
                if (window.__fluxdoHooked) return;
                window.__fluxdoHooked = true;
                var checked = false;
                var attempts = 0;
                var maxAttempts = 30;
                function check() {
                    if (checked || attempts >= maxAttempts) return;
                    attempts++;
                    try {
                        var meta = document.querySelector('meta[name="current-username"]');
                        var uname = '';
                        if (meta && meta.content) {
                            uname = meta.content.trim();
                        } else if (typeof Discourse !== 'undefined' && Discourse.User && Discourse.User.current()) {
                            uname = Discourse.User.current().username || '';
                        }
                        if (uname) {
                            checked = true;
                            var csrfMeta = document.querySelector('meta[name="csrf-token"]');
                            var csrf = csrfMeta ? csrfMeta.content : '';
                            window.webkit.messageHandlers.\(messageHandlerName).postMessage({
                                type: 'login',
                                username: uname,
                                csrf: csrf
                            });
                            return;
                        }
                    } catch(e) {}
                    setTimeout(check, 500);
                }
                check();
            })();
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(script)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        let url = AppConstants.baseURL.appendingPathComponent("/login")
        var req = URLRequest(url: url)
        req.setValue(AppConstants.userAgent, forHTTPHeaderField: "User-Agent")
        req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        webView.load(req)

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        let onLoginDetected: ([HTTPCookie], String, String) -> Void

        init(onLoginDetected: @escaping ([HTTPCookie], String, String) -> Void) {
            self.onLoginDetected = onLoginDetected
        }

        // MARK: - WKScriptMessageHandler

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == messageHandlerName,
                  let body = message.body as? [String: Any],
                  let type = body["type"] as? String,
                  type == "login",
                  let username = body["username"] as? String,
                  let csrfFromPage = body["csrf"] as? String
            else { return }

            // 登录已处理
            guard !username.isEmpty else { return }

            let webView = (message.webView)!
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
                guard let self else { return }
                let targets = cookies.filter { $0.domain.contains("linux.do") }

                // CSRF 优先用页面的 meta，降级则 fetch /session/csrf
                let csrfToken = csrfFromPage.isEmpty ? "" : csrfFromPage
                if !csrfToken.isEmpty {
                    Task { @MainActor in
                        await CookieBridge.shared.syncFromWebView(dataStore: .nonPersistent())
                        self.onLoginDetected(targets, csrfToken, username)
                    }
                } else {
                    self.fetchCSRFToken(cookies: cookies) { fetchedCSRF in
                        Task { @MainActor in
                            await CookieBridge.shared.syncFromWebView(dataStore: .nonPersistent())
                            self.onLoginDetected(targets, fetchedCSRF, username)
                        }
                    }
                }
            }
        }

        // MARK: - Navigation

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // 额外检查：注入脚本可能因页面完全 SPA 而无 atDocumentEnd 触发
            // 手动补一针 evaluatoeJavaScript
            webView.evaluateJavaScript("""
            (function() {
                var meta = document.querySelector('meta[name="current-username"]');
                if (meta && meta.content) {
                    return meta.content.trim();
                }
                if (typeof Discourse !== 'undefined' && Discourse.User && Discourse.User.current()) {
                    return Discourse.User.current().username || '';
                }
                return '';
            })();
            """) { [weak self] result, _ in
                guard let self, let username = result as? String, !username.isEmpty else { return }
                webView.evaluateJavaScript("document.querySelector('meta[name=\"csrf-token\"]')?.content") { csrfResult, _ in
                    let csrf = (csrfResult as? String) ?? ""
                    webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                        let targets = cookies.filter { $0.domain.contains("linux.do") }
                        Task { @MainActor in
                            await CookieBridge.shared.syncFromWebView(dataStore: .nonPersistent())
                            self.onLoginDetected(targets, csrf, username)
                        }
                    }
                }
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == -999 { return }
            print("[LoginWebView] 预加载失败: \(error.localizedDescription)")
        }

        // MARK: - OAuth Popup

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }

        // MARK: - Fallback CSRF Fetch

        private func fetchCSRFToken(cookies: [HTTPCookie], completion: @escaping (String) -> Void) {
            var req = URLRequest(url: AppConstants.baseURL.appendingPathComponent(AppConstants.csrfEndpoint))
            req.setValue(AppConstants.userAgent, forHTTPHeaderField: "User-Agent")
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            let headers = HTTPCookie.requestHeaderFields(with: cookies)
            for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
            URLSession.shared.dataTask(with: req) { data, _, _ in
                guard let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let csrf = json["csrf"] as? String
                else { completion(""); return }
                completion(csrf)
            }.resume()
        }
    }
}
