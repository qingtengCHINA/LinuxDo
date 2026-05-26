//
//  TimeUtils.swift
//  LinuxDo
//
//  Discourse API 时间统一处理：UTC 解析 → 本地显示
//  参考 fluxdo lib/utils/time_utils.dart
//

import Foundation

enum TimeUtils {

    /// Discourse API 默认时间格式（UTC）
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// 无小数秒的降级格式
    private static let isoFormatterNoFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    // MARK: - Parse

    /// 解析 API 返回的 UTC 时间字符串，返回本地时区的 Date?
    /// 支持 "2024-01-15T10:30:00.000Z" 和 "2024-01-15T10:30:00Z"
    static func parseUTC(_ string: String?) -> Date? {
        guard let s = string else { return nil }
        if let d = isoFormatter.date(from: s) { return d }
        return isoFormatterNoFraction.date(from: s)
    }

    // MARK: - Format

    /// 相对时间（刚刚 / N 分钟前 / N 小时前 / N 天前 / N 月前 / N 年前）
    static func relative(from date: Date?) -> String {
        guard let date else { return "" }
        let now = Date()
        let diff = now.timeIntervalSince(date)

        if diff < 60 { return "刚刚" }
        if diff < 3600 { return "\(Int(diff / 60)) 分钟前" }
        if diff < 86400 { return "\(Int(diff / 3600)) 小时前" }
        if diff < 2592000 { return "\(Int(diff / 86400)) 天前" }
        if diff < 31536000 { return "\(Int(diff / 2592000)) 个月前" }
        return "\(Int(diff / 31536000)) 年前"
    }

    /// 详细时间格式：2024/01/15 10:30
    static func detail(from date: Date?) -> String {
        guard let date else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy/MM/dd HH:mm"
        return f.string(from: date)
    }

    /// 紧凑格式：01-15 10:30
    static func compact(from date: Date?) -> String {
        guard let date else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "MM-dd HH:mm"
        return f.string(from: date)
    }
}
