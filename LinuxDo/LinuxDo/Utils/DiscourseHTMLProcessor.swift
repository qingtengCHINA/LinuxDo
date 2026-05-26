//
//  DiscourseHTMLProcessor.swift
//  LinuxDo
//
//  Small cooked-HTML normalization layer shared by WKWebView rendering and tests.
//

import Foundation

enum DiscourseHTMLProcessor {
    static func normalize(_ raw: String, baseURL: URL = AppConstants.baseURL) -> String {
        var html = raw
        html = absolutizeAttributes(in: html, attribute: "src", baseURL: baseURL)
        html = absolutizeAttributes(in: html, attribute: "href", baseURL: baseURL)
        html = html.replacingOccurrences(of: "srcset=\"//", with: "srcset=\"https://")
        html = html.replacingOccurrences(of: "data-src=\"//", with: "data-src=\"https://")
        html = absolutizeAttributes(in: html, attribute: "data-src", baseURL: baseURL)
        html = absolutizeAttributes(in: html, attribute: "data-thumbnail-src", baseURL: baseURL)
        return html
    }

    static func scriptJSON<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(value),
              let raw = String(data: data, encoding: .utf8)
        else { return "[]" }

        return raw
            .replacingOccurrences(of: "&", with: "\\u0026")
            .replacingOccurrences(of: "<", with: "\\u003C")
            .replacingOccurrences(of: ">", with: "\\u003E")
            .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
            .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
    }

    private static func absolutizeAttributes(in html: String, attribute: String, baseURL: URL) -> String {
        let pattern = "(?i)\\b\(NSRegularExpression.escapedPattern(for: attribute))\\s*=\\s*([\"'])(.*?)\\1"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return html }

        let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
        let matches = regex.matches(in: html, range: nsRange).reversed()
        var result = html

        for match in matches {
            guard match.numberOfRanges >= 3,
                  let quoteRange = Range(match.range(at: 1), in: result),
                  let valueRange = Range(match.range(at: 2), in: result),
                  let fullRange = Range(match.range(at: 0), in: result)
            else { continue }

            let quote = String(result[quoteRange])
            let value = String(result[valueRange])
            guard let absolute = absoluteURLString(value, baseURL: baseURL) else { continue }
            result.replaceSubrange(fullRange, with: "\(attribute)=\(quote)\(absolute)\(quote)")
        }

        return result
    }

    private static func absoluteURLString(_ value: String, baseURL: URL) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let lower = trimmed.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") || lower.hasPrefix("data:") || lower.hasPrefix("mailto:") || lower.hasPrefix("javascript:") {
            return nil
        }
        if trimmed.hasPrefix("//") {
            return "https:\(trimmed)"
        }
        if trimmed.hasPrefix("/") {
            return baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + trimmed
        }
        guard !trimmed.hasPrefix("#"),
              let resolved = URL(string: trimmed, relativeTo: baseURL)?.absoluteURL
        else { return nil }
        return resolved.absoluteString
    }
}
