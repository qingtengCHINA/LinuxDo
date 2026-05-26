//
//  DiscourseWebView.swift
//  LinuxDo
//
//  WKWebView-based Discourse HTML renderer.
//  Replaces NSAttributedString(html:) — proper dark mode + font scaling + link handling.
//  Height: JavaScript ResizeObserver + scrollHeight, NOT estimates.
//

import SwiftUI
import WebKit

struct PollVotePayload: Decodable, Equatable {
    let postID: Int
    let pollName: String
    let options: [String]
}

struct DiscourseWebView: UIViewRepresentable {
    let html: String
    var baseFontSize: CGFloat = 15
    var postID: Int?
    var polls: [Poll] = []
    var pollVotes: [String: [String]] = [:]
    var onImageTap: ((String) -> Void)?
    var onLinkTap: ((URL) -> Void)?
    var onPollVote: ((PollVotePayload) -> Void)?
    var onPollRemoveVote: ((PollVotePayload) -> Void)?

    @Binding var contentHeight: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let ctrl = config.userContentController
        ctrl.add(WeakScriptMessageHandler(context.coordinator), name: "heightUpdate")
        ctrl.add(WeakScriptMessageHandler(context.coordinator), name: "imageTap")
        ctrl.add(WeakScriptMessageHandler(context.coordinator), name: "linkTap")
        ctrl.add(WeakScriptMessageHandler(context.coordinator), name: "pollVote")
        ctrl.add(WeakScriptMessageHandler(context.coordinator), name: "pollRemoveVote")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.bouncesZoom = false
        webView.navigationDelegate = context.coordinator

        context.coordinator.webView = webView
        context.coordinator.parent = self

        // Height observer JS — fires on load + content resize
        let heightJS = """
        (function() {
            function notifyHeight() {
                var h = document.documentElement.scrollHeight || document.body.scrollHeight;
                window.webkit.messageHandlers.heightUpdate.postMessage(String(h));
            }
            var ro = new ResizeObserver(function() { notifyHeight(); });
            ro.observe(document.body);
            // Also observe after images load
            document.addEventListener('load', function(e) {
                if (e.target.tagName === 'IMG') setTimeout(notifyHeight, 50);
            }, true);
            // Initial
            setTimeout(notifyHeight, 50);
            setTimeout(notifyHeight, 300);
        })();
        """
        ctrl.addUserScript(WKUserScript(source: heightJS, injectionTime: .atDocumentEnd, forMainFrameOnly: true))

        let bridgeJS = """
        (function() {
            function send(type, data) { window.webkit.messageHandlers[type].postMessage(data); }

            function readJSON(id, fallback) {
                try {
                    var node = document.getElementById(id);
                    if (!node) return fallback;
                    return JSON.parse(node.textContent || '');
                } catch (_) {
                    return fallback;
                }
            }

            function plainText(html) {
                var div = document.createElement('div');
                div.innerHTML = html || '';
                return div.textContent || div.innerText || '';
            }

            function optionHTML(option, selected, total, showResults) {
                var votes = Number(option.votes || 0);
                var percent = total > 0 ? Math.round((votes / total) * 100) : 0;
                var bar = showResults ? '<span class="poll-result-bar" style="width:' + percent + '%"></span>' : '';
                var stat = showResults ? '<span class="poll-stat">' + percent + '% · ' + votes + '</span>' : '';
                return '<button class="poll-option-button' + (selected ? ' selected' : '') + '" data-option-id="' + option.id + '">' +
                    bar +
                    '<span class="poll-choice">' + (selected ? '✓' : '') + '</span>' +
                    '<span class="poll-option-label">' + plainText(option.html) + '</span>' +
                    stat +
                    '</button>';
            }

            function renderPolls() {
                var polls = readJSON('linuxdo-polls-json', []);
                var votes = readJSON('linuxdo-poll-votes-json', {});
                var postId = Number(document.body.getAttribute('data-post-id') || '0');
                if (!polls.length || !postId) return;

                polls.forEach(function(poll) {
                    var selector = '.poll[data-poll-name="' + CSS.escape(poll.name || 'poll') + '"]';
                    var nodes = document.querySelectorAll(selector);
                    if (!nodes.length) nodes = document.querySelectorAll('.poll');
                    nodes.forEach(function(node) {
                        if (node.getAttribute('data-linuxdo-enhanced') === '1') return;
                        node.setAttribute('data-linuxdo-enhanced', '1');
                        var selected = votes[poll.name] || [];
                        var total = (poll.options || []).reduce(function(sum, option) { return sum + Number(option.votes || 0); }, 0);
                        var closed = poll.status === 'closed';
                        var showResults = selected.length > 0 || closed || poll.results === 'always';
                        var title = node.getAttribute('data-poll-question') || node.querySelector('.poll-title, .poll-question')?.textContent || '';
                        var html = '<div class="poll-card" data-poll-name="' + (poll.name || 'poll') + '">' +
                            (title ? '<div class="poll-title-enhanced">' + title + '</div>' : '') +
                            '<div class="poll-options">' +
                            (poll.options || []).map(function(option) {
                                return optionHTML(option, selected.indexOf(String(option.id)) >= 0, total, showResults);
                            }).join('') +
                            '</div>' +
                            '<div class="poll-footer">' +
                            '<span>' + (closed ? '已关闭' : (poll.voters || 0) + ' 投票人') + '</span>' +
                            (selected.length > 0 && !closed ? '<button class="poll-undo">撤销</button>' : '') +
                            '</div>' +
                            '</div>';
                        node.innerHTML = html;

                        node.querySelectorAll('.poll-option-button').forEach(function(button) {
                            button.addEventListener('click', function() {
                                if (closed) return;
                                var optionId = button.getAttribute('data-option-id');
                                var next = poll.type === 'multiple' ? selected.slice() : [optionId];
                                if (poll.type === 'multiple') {
                                    var idx = next.indexOf(optionId);
                                    if (idx >= 0) next.splice(idx, 1); else next.push(optionId);
                                }
                                send('pollVote', { postID: postId, pollName: poll.name || 'poll', options: next });
                            });
                        });

                        var undo = node.querySelector('.poll-undo');
                        if (undo) {
                            undo.addEventListener('click', function(e) {
                                e.preventDefault();
                                send('pollRemoveVote', { postID: postId, pollName: poll.name || 'poll', options: [] });
                            });
                        }
                    });
                });
            }

            document.addEventListener('click', function(e) {
                var img = e.target;
                if (img.tagName === 'IMG') {
                    e.preventDefault(); e.stopPropagation();
                    var src = img.getAttribute('src') || img.getAttribute('data-src') || '';
                    if (src && !src.startsWith('data:')) { send('imageTap', src); return;
                }
                var lb = e.target.closest('a.lightbox');
                if (lb) {
                    e.preventDefault(); e.stopPropagation();
                    var href = lb.getAttribute('href') || '';
                    if (href) send('imageTap', href);
                    return;
                }
            }, true);

            document.addEventListener('click', function(e) {
                var link = e.target.closest('a');
                if (link) {
                    var href = link.getAttribute('href') || '';
                    if (!href || href.startsWith('#') || href.startsWith('javascript:')) return;
                    if (link.classList.contains('lightbox')) return;
                    if (link.classList.contains('mention')) return;
                    e.preventDefault();
                    send('linkTap', href);
                }
            }, true);

            document.addEventListener('click', function(e) {
                var sp = e.target.closest('.spoiler, .spoiled');
                if (sp) sp.classList.toggle('revealed');
            });

            setTimeout(renderPolls, 0);
            setTimeout(renderPolls, 250);
        })();
        """
        ctrl.addUserScript(WKUserScript(source: bridgeJS, injectionTime: .atDocumentEnd, forMainFrameOnly: true))

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        let styled = buildStyledHTML(html, fontSize: baseFontSize, isDark: colorScheme == .dark)
        if context.coordinator.loadedHTML != styled {
            context.coordinator.loadedHTML = styled
            webView.loadHTMLString(styled, baseURL: AppConstants.baseURL)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.stopLoading()
        webView.navigationDelegate = nil
        let ctrl = webView.configuration.userContentController
        ["heightUpdate", "imageTap", "linkTap", "pollVote", "pollRemoveVote"].forEach {
            ctrl.removeScriptMessageHandler(forName: $0)
        }
        coordinator.webView = nil
        coordinator.parent = nil
        coordinator.loadedHTML = nil
    }

    class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        weak var webView: WKWebView?
        var parent: DiscourseWebView?
        var loadedHTML: String?

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "heightUpdate":
                guard let body = message.body as? String else { return }
                if let h = Double(body) {
                    DispatchQueue.main.async {
                        let next = max(CGFloat(h), 20)
                        if let current = self.parent?.contentHeight, abs(current - next) > 1 {
                            self.parent?.contentHeight = next
                        }
                    }
                }
            case "imageTap":
                guard let body = message.body as? String else { return }
                parent?.onImageTap?(body)
            case "linkTap":
                guard let body = message.body as? String else { return }
                if let url = URL(string: body, relativeTo: URL(string: "https://linux.do")) {
                    parent?.onLinkTap?(url)
                }
            case "pollVote":
                if let payload = decodePollPayload(message.body) {
                    parent?.onPollVote?(payload)
                }
            case "pollRemoveVote":
                if let payload = decodePollPayload(message.body) {
                    parent?.onPollRemoveVote?(payload)
                }
            default: break
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("document.documentElement.scrollHeight || document.body.scrollHeight") { result, _ in
                if let h = result as? CGFloat {
                    DispatchQueue.main.async {
                        let next = max(h, 20)
                        if let current = self.parent?.contentHeight, abs(current - next) > 1 {
                            self.parent?.contentHeight = next
                        }
                    }
                }
            }
        }

        private func decodePollPayload(_ body: Any) -> PollVotePayload? {
            guard let dict = body as? [String: Any],
                  JSONSerialization.isValidJSONObject(dict),
                  let data = try? JSONSerialization.data(withJSONObject: dict)
            else { return nil }
            return try? JSONDecoder().decode(PollVotePayload.self, from: data)
        }
    }

    private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
        weak var target: WKScriptMessageHandler?

        init(_ target: WKScriptMessageHandler) {
            self.target = target
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            target?.userContentController(userContentController, didReceive: message)
        }
    }

    // MARK: - HTML + CSS

    private func buildStyledHTML(_ raw: String, fontSize: CGFloat, isDark: Bool) -> String {
        let bg = isDark ? "#1c1c1e" : "#ffffff"
        let text = isDark ? "#e5e5e7" : "#1c1c1e"
        let text2 = isDark ? "#8e8e93" : "#6e6e73"
        let link = isDark ? "#64d2ff" : "#007aff"
        let codeBg = isDark ? "#2c2c2e" : "#f5f5f7"
        let codeFg = isDark ? "#ff6b8a" : "#c7254e"
        let bqBorder = isDark ? "#64d2ff" : "#007aff"
        let bqBg = isDark ? "#1e2a3a" : "#f0f5ff"
        let spoilerBg = isDark ? "#3a3a3c" : "#e5e5ea"
        let header = isDark ? "#ffffff" : "#1c1c1e"
        let hr = isDark ? "#48484a" : "#d1d1d6"
        let mentionBg = isDark ? "#2c3e50" : "#e8f0fe"

        let processed = DiscourseHTMLProcessor.normalize(raw)
        let pollsJSON = DiscourseHTMLProcessor.scriptJSON(polls)
        let pollVotesJSON = DiscourseHTMLProcessor.scriptJSON(pollVotes)
        let postIDAttr = postID.map(String.init) ?? ""

        return """
        <!DOCTYPE html><html><head>
        <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=5,user-scalable=yes">
        <meta name="color-scheme" content="\(isDark ? "dark" : "light")">
        <style>
        :root { color-scheme: \(isDark ? "dark" : "light"); }
        * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
        body {
            font-family: 'Times New Roman','Georgia','Noto Serif CJK SC','STSongti-SC',serif;
            font-size: \(fontSize)px; line-height: 1.65; color: \(text); background: \(bg);
            margin: 0; padding: 0; -webkit-text-size-adjust: 100%;
            word-wrap: break-word; overflow-wrap: break-word;
        }
        h1 { font-size: \(fontSize*1.5)px; font-weight: 700; color: \(header); margin: 16px 0 8px; }
        h2 { font-size: \(fontSize*1.3)px; font-weight: 700; color: \(header); margin: 14px 0 6px; }
        h3 { font-size: \(fontSize*1.15)px; font-weight: 600; color: \(header); margin: 12px 0 6px; }
        h4 { font-size: \(fontSize*1.05)px; font-weight: 600; color: \(header); margin: 10px 0 4px; }
        p { margin: 0 0 10px; }
        a { color: \(link); text-decoration: none; }
        a:hover { text-decoration: underline; }
        img { max-width: 100%; height: auto; border-radius: 6px; margin: 6px 0; vertical-align: middle; display: block; }
        img.emoji, img.custom-emoji, .emoji img {
            width: 1.35em; height: 1.35em; min-width: 1.35em; min-height: 1.35em;
            display: inline-block; vertical-align: -0.25em; border-radius: 0; margin: 0 2px;
            object-fit: contain;
        }
        .emoji { width: 1.35em; height: 1.35em; display: inline-block; vertical-align: -0.25em; }
        code {
            font-family: 'SF Mono','Menlo','Monaco',monospace; font-size: \(fontSize-2)px;
            background: \(codeBg); color: \(codeFg); padding: 2px 5px; border-radius: 3px;
            word-break: break-word;
        }
        pre {
            background: \(codeBg); border-radius: 8px; padding: 12px; margin: 10px 0;
            overflow-x: auto; -webkit-overflow-scrolling: touch;
        }
        pre code { background: none; color: inherit; padding: 0; border-radius: 0; font-size: \(fontSize-1)px; white-space: pre-wrap; word-break: break-word; }
        blockquote { border-left: 4px solid \(bqBorder); background: \(bqBg); padding: 10px 12px; margin: 10px 0; border-radius: 0 6px 6px 0; color: \(text2); }
        blockquote p:last-child { margin-bottom: 0; }
        ul, ol { padding-left: 24px; margin: 8px 0; }
        li { margin: 3px 0; line-height: 1.5; }
        table { border-collapse: collapse; width: 100%; margin: 10px 0; font-size: \(fontSize-1)px; display: block; overflow-x: auto; }
        th, td { border: 1px solid \(hr); padding: 6px 10px; text-align: left; }
        th { background: \(codeBg); font-weight: 600; }
        hr { border: none; border-top: 1px solid \(hr); margin: 16px 0; }
        .spoiler, .spoiled { background: \(spoilerBg); color: transparent; border-radius: 4px; padding: 2px 4px; cursor: pointer; transition: all 0.3s; user-select: none; }
        .spoiler.revealed, .spoiled.revealed { background: transparent; color: inherit; }
        details { background: \(codeBg); border-radius: 6px; margin: 8px 0; }
        summary { padding: 8px 12px; font-weight: 500; cursor: pointer; color: \(link); list-style: none; }
        summary::-webkit-details-marker { display: none; }
        summary::before { content: '\\25B6 '; font-size: 10px; }
        details[open] summary::before { content: '\\25BC '; }
        details > *:not(summary) { padding: 0 12px 8px; }
        .onebox, aside.onebox {
            background: \(codeBg); border-radius: 8px; padding: 12px; margin: 10px 0;
            border: 1px solid \(hr); display: block; overflow: hidden;
        }
        .onebox .source, aside.onebox header.source {
            font-size: 12px; color: \(text2); display: flex; gap: 6px; align-items: center; margin-bottom: 8px;
        }
        .onebox .source img, aside.onebox header.source img, img.site-icon {
            width: 16px; height: 16px; border-radius: 4px; display: inline-block; margin: 0;
        }
        .onebox h3, .onebox h4, aside.onebox h3, aside.onebox h4 {
            font-size: \(fontSize)px; line-height: 1.35; margin: 4px 0; color: \(header);
        }
        .onebox p, aside.onebox p { color: \(text2); font-size: \(fontSize-1)px; margin: 4px 0 0; }
        .onebox img.thumbnail, aside.onebox img.thumbnail, .onebox .thumbnail img {
            float: right; width: 76px; max-height: 76px; object-fit: cover; margin: 0 0 8px 12px;
        }
        a.mention { display: inline-block; background: \(mentionBg); color: \(link); padding: 1px 6px; border-radius: 4px; font-size: \(fontSize-1)px; }
        aside.quote { border-left: 4px solid \(bqBorder); background: \(bqBg); padding: 10px 12px; margin: 10px 0; border-radius: 0 6px 6px 0; }
        aside.quote .title { font-weight: 600; font-size: \(fontSize-1)px; color: \(text2); margin-bottom: 6px; }
        .poll, .poll-card {
            background: \(codeBg); border-radius: 8px; padding: 12px; margin: 10px 0;
            border: 1px solid \(hr);
        }
        .poll-title-enhanced { font-weight: 700; color: \(header); margin-bottom: 8px; }
        .poll-options { display: grid; gap: 8px; }
        .poll-option-button {
            position: relative; overflow: hidden; min-height: 42px; width: 100%;
            display: flex; align-items: center; gap: 8px; padding: 8px 10px;
            border: 1px solid \(hr); border-radius: 7px; background: \(bg); color: \(text);
            font-family: inherit; font-size: \(fontSize)px; text-align: left;
        }
        .poll-option-button.selected { border-color: \(link); color: \(link); }
        .poll-result-bar {
            position: absolute; left: 0; top: 0; bottom: 0; background: \(link); opacity: 0.12;
        }
        .poll-choice, .poll-option-label, .poll-stat { position: relative; z-index: 1; }
        .poll-choice { width: 18px; text-align: center; color: \(link); font-weight: 700; }
        .poll-option-label { flex: 1; }
        .poll-stat { color: \(text2); font-size: \(fontSize-2)px; }
        .poll-footer { display: flex; justify-content: space-between; align-items: center; margin-top: 8px; color: \(text2); font-size: \(fontSize-2)px; }
        .poll-undo { border: 0; color: \(link); background: transparent; font: inherit; padding: 4px; }
        .chat-transcript { background: \(codeBg); border-radius: 8px; padding: 12px; margin: 10px 0; }
        .math { font-style: italic; }
        .footnote-ref { font-size: \(fontSize-3)px; vertical-align: super; }
        .callout { border-radius: 8px; padding: 12px; margin: 10px 0; }
        .d-icon { display: none; }
        .lightbox { cursor: pointer; display: inline-block; }
        aside.onebox-avatar { display: none; }
        .cooked { line-height: 1.65; }
        .post-menu-area { display: none; }
        </style></head><body data-post-id="\(postIDAttr)">
        <script id="linuxdo-polls-json" type="application/json">\(pollsJSON)</script>
        <script id="linuxdo-poll-votes-json" type="application/json">\(pollVotesJSON)</script>
        \(processed)
        </body></html>
        """
    }
}

struct DiscourseWebViewWrapper: View {
    let html: String
    var baseFontSize: CGFloat = 15
    var postID: Int?
    var polls: [Poll] = []
    var pollVotes: [String: [String]] = [:]
    var onImageTap: ((String) -> Void)?
    var onLinkTap: ((URL) -> Void)?
    var onPollVote: ((PollVotePayload) -> Void)?
    var onPollRemoveVote: ((PollVotePayload) -> Void)?

    @State private var contentHeight: CGFloat = 20

    var body: some View {
        DiscourseWebView(
            html: html,
            baseFontSize: baseFontSize,
            postID: postID,
            polls: polls,
            pollVotes: pollVotes,
            onImageTap: onImageTap,
            onLinkTap: onLinkTap,
            onPollVote: onPollVote,
            onPollRemoveVote: onPollRemoveVote,
            contentHeight: $contentHeight
        )
        .frame(height: max(contentHeight, 20))
    }
}
