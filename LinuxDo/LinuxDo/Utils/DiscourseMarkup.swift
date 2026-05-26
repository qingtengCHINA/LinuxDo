//
//  DiscourseMarkup.swift
//  LinuxDo
//
//  Robust Discourse markup stripping — handles HTML entities, emoji shortcodes, onebox, quotes

import Foundation

extension String {

    /// Strip all Discourse markup (HTML tags, entities, emoji shortcodes, onebox remnants)
    /// producing clean plain text suitable for display.
    func strippingDiscourseMarkup() -> String {
        var text = self

        // 1. Remove onebox divs entirely (they embed external content)
        text = text.replacingOccurrences(of: "<div[^>]*class=\"[^\"]*onebox[^\"]*\"[^>]*>.*?</div>",
                                         with: "", options: .regularExpression)

        // 2. Remove blockquotes content marker
        text = text.replacingOccurrences(of: "<aside[^>]*>.*?</aside>",
                                         with: "", options: .regularExpression)

        // 3. Remove all remaining HTML tags
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

        // 4. Decode common HTML entities
        text = decodeHTMLEntities()

        // 5. Convert Discourse emoji shortcodes like :smile: → 😊 (leave as-is if unknown)
        text = convertEmojiShortcodes()

        // 6. Collapse whitespace
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Decode HTML entities — handles named, decimal, and hex entities
    private func decodeHTMLEntities() -> String {
        var result = self

        // Named entities
        let namedEntities: [String: String] = [
            "&amp;": "&", "&lt;": "<", "&gt;": ">",
            "&quot;": "\"", "&apos;": "'", "&nbsp;": " ",
            "&mdash;": "—", "&ndash;": "–", "&laquo;": "«", "&raquo;": "»",
            "&hellip;": "…", "&bull;": "•", "&middot;": "·",
            "&copy;": "©", "&reg;": "®", "&trade;": "™",
            "&ldquo;": "\u{201C}", "&rdquo;": "\u{201D}",
            "&lsquo;": "\u{2018}", "&rsquo;": "\u{2019}",
        ]
        for (entity, char) in namedEntities {
            result = result.replacingOccurrences(of: entity, with: char)
        }

        // Decimal entities: &#123; or &#1234;
        result = result.replacingOccurrences(of: "&#([0-9]+);", with: { match in
            guard let group1 = match.group(1), let code = UInt32(group1), let scalar = UnicodeScalar(code) else {
                return match.group(0) ?? ""
            }
            return String(scalar)
        })

        result = result.replacingOccurrences(of: "&#x([0-9a-fA-F]+);", with: { match in
            guard let group1 = match.group(1), let code = UInt32(group1, radix: 16), let scalar = UnicodeScalar(code) else {
                return match.group(0) ?? ""
            }
            return String(scalar)
        })

        return result
    }

    /// Convert common Discourse emoji shortcodes to Unicode
    private func convertEmojiShortcodes() -> String {
        var text = self
        let emojis: [String: String] = [
            ":smile:": "😄", ":slight_smile:": "🙂", ":grinning:": "😀",
            ":wink:": "😉", ":laughing:": "😆", ":heart:": "❤️",
            ":thumbsup:": "👍", ":+1:": "👍", ":-1:": "👎",
            ":thinking:": "🤔", ":joy:": "😂", ":rofl:": "🤣",
            ":cry:": "😢", ":sob:": "😭", ":angry:": "😠",
            ":fire:": "🔥", ":star:": "⭐", ":eyes:": "👀",
            ":clap:": "👏", ":pray:": "🙏", ":coffee:": "☕",
            ":rocket:": "🚀", ":check:": "✅", ":x:": "❌",
            ":warning:": "⚠️", ":link:": "🔗", ":memo:": "📝",
            ":point_up:": "☝️", ":handshake:": "🤝",
            ":tada:": "🎉", ":100:": "💯", ":muscle:": "💪",
            ":custard:": "🍮", ":doughnut:": "🍩",
            ":stuck_out_tongue:": "😛", ":neutral_face:": "😐",
            ":hushed:": "😯", ":frowning:": "😦", ":open_mouth:": "😮",
            ":scream:": "😱", ":sleepy:": "😪", ":confused:": "😕",
            ":stuck_out_tongue_winking_eye:": "😜",
        ]
        for (shortcode, unicode) in emojis {
            text = text.replacingOccurrences(of: shortcode, with: unicode)
        }
        // Remove unknown shortcodes like :some_emoji_name: entirely
        text = text.replacingOccurrences(of: ":[a-z_]+:", with: "", options: .regularExpression)
        return text
    }
}

// MARK: - Regex match helper

private struct RegexMatch {
    let group: (Int) -> String?
}

private extension String {
    func replacingOccurrences(of pattern: String, with transform: (RegexMatch) -> String, options: NSRegularExpression.Options = []) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return self }
        let nsRange = NSRange(self.startIndex..., in: self)
        let matches = regex.matches(in: self, range: nsRange)

        var result = self
        for match in matches.reversed() {
            let groups = RegexMatch { groupIdx in
                guard match.numberOfRanges > groupIdx else { return nil }
                let range = match.range(at: groupIdx)
                guard range.location != NSNotFound else { return nil }
                let swiftRange = Range(range, in: self)
                return swiftRange.map { String(self[$0]) }
            }
            let fullRange = Range(match.range, in: self)!
            let replacement = transform(groups)
            result.replaceSubrange(fullRange, with: replacement)
        }
        return result
    }
}