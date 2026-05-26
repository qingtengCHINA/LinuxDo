//
//  MessageBusService.swift
//  LinuxDo
//
//  Discourse MessageBus long-polling client. This is the realtime backbone used by
//  latest-topic badges and topic-detail post refreshes.
//

import Foundation

enum MessageBusJSONValue: Codable, Equatable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case object([String: MessageBusJSONValue])
    case array([MessageBusJSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: MessageBusJSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([MessageBusJSONValue].self) {
            self = .array(value)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var intValue: Int? {
        switch self {
        case .int(let value): return value
        case .double(let value): return Int(value)
        case .string(let value): return Int(value)
        default: return nil
        }
    }

    var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    var objectValue: [String: MessageBusJSONValue]? {
        if case .object(let value) = self { return value }
        return nil
    }
}

struct MessageBusMessage: Decodable, Equatable, Sendable {
    let channel: String
    let messageID: Int
    let data: [String: MessageBusJSONValue]

    enum CodingKeys: String, CodingKey {
        case channel
        case messageID = "message_id"
        case data
    }

    init(channel: String, messageID: Int, data: [String: MessageBusJSONValue]) {
        self.channel = channel
        self.messageID = messageID
        self.data = data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        channel = try container.decode(String.self, forKey: .channel)
        messageID = try container.decode(Int.self, forKey: .messageID)
        data = (try? container.decode([String: MessageBusJSONValue].self, forKey: .data)) ?? [:]
    }
}

typealias MessageBusCallback = @MainActor (MessageBusMessage) -> Void

@MainActor
final class MessageBusService {
    static let shared = MessageBusService()

    private struct ChannelSubscription {
        var lastMessageID: Int
        var callbacks: [UUID: MessageBusCallback]
    }

    private let clientID: String
    private let session: URLSession
    private var subscriptions: [String: ChannelSubscription] = [:]
    private var tokenChannels: [UUID: String] = [:]
    private var pollTask: Task<Void, Never>?
    private var failureCount = 0
    private var lastPollDate: Date?

    private init() {
        clientID = "ios-\(UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased())"
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 65
        config.timeoutIntervalForResource = 75
        config.httpCookieStorage = .shared
        session = URLSession(configuration: config)
    }

    @discardableResult
    func subscribe(_ channel: String, lastMessageID: Int = -1, callback: @escaping MessageBusCallback) -> UUID {
        let token = UUID()
        var sub = subscriptions[channel] ?? ChannelSubscription(lastMessageID: lastMessageID, callbacks: [:])
        sub.lastMessageID = max(sub.lastMessageID, lastMessageID)
        sub.callbacks[token] = callback
        subscriptions[channel] = sub
        tokenChannels[token] = channel
        ensurePolling()
        return token
    }

    func unsubscribe(_ token: UUID?) {
        guard let token, let channel = tokenChannels[token] else { return }
        tokenChannels[token] = nil
        subscriptions[channel]?.callbacks[token] = nil
        if subscriptions[channel]?.callbacks.isEmpty == true {
            subscriptions[channel] = nil
        }
        if subscriptions.isEmpty {
            stopPolling()
        }
    }

    func stopAll() {
        subscriptions.removeAll()
        tokenChannels.removeAll()
        stopPolling()
    }

    nonisolated static func parseMessages(from raw: String) -> [MessageBusMessage] {
        raw
            .split(separator: "|")
            .flatMap { chunk -> [MessageBusMessage] in
                let trimmed = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return [] }
                return (try? JSONDecoder().decode([MessageBusMessage].self, from: data)) ?? []
            }
    }

    private func ensurePolling() {
        guard pollTask == nil, !subscriptions.isEmpty else { return }
        pollTask = Task { [weak self] in
            await self?.pollLoop()
        }
    }

    private func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
        failureCount = 0
    }

    private func pollLoop() async {
        while !Task.isCancelled {
            guard !subscriptions.isEmpty else {
                pollTask = nil
                return
            }

            if let lastPollDate {
                let elapsed = Date().timeIntervalSince(lastPollDate)
                if elapsed < 0.1 {
                    try? await Task.sleep(nanoseconds: UInt64((0.1 - elapsed) * 1_000_000_000))
                }
            }

            do {
                lastPollDate = Date()
                let messages = try await pollOnce()
                failureCount = 0
                handle(messages)
            } catch is CancellationError {
                pollTask = nil
                return
            } catch {
                failureCount += 1
                let delay = min(pow(2.0, Double(failureCount)), 30.0)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        pollTask = nil
    }

    private func pollOnce() async throws -> [MessageBusMessage] {
        let snapshot = subscriptions.mapValues(\.lastMessageID)
        var request = URLRequest(url: AppConstants.baseURL.appendingPathComponent("message-bus/\(clientID)/poll"))
        request.httpMethod = "POST"
        request.setValue(AppConstants.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("true", forHTTPHeaderField: "Discourse-Background")
        request.httpBody = Self.formBody(snapshot.map { ($0.key, "\($0.value)") })

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { return [] }
        if http.statusCode == 429 {
            let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap(Double.init) ?? 60
            try await Task.sleep(nanoseconds: UInt64(retryAfter * 1_000_000_000))
            return []
        }
        guard (200...299).contains(http.statusCode) else { return [] }
        return Self.parseMessages(from: String(data: data, encoding: .utf8) ?? "")
    }

    private func handle(_ messages: [MessageBusMessage]) {
        for message in messages {
            if message.channel == "/__status" {
                for (channel, value) in message.data {
                    if let id = value.intValue, subscriptions[channel] != nil {
                        subscriptions[channel]?.lastMessageID = id
                    }
                }
                continue
            }

            guard var sub = subscriptions[message.channel] else { continue }
            sub.lastMessageID = max(sub.lastMessageID, message.messageID)
            subscriptions[message.channel] = sub
            for callback in sub.callbacks.values {
                callback(message)
            }
        }
    }

    nonisolated private static func formBody(_ pairs: [(String, String)]) -> Data? {
        pairs
            .map { "\($0.0.formEncoded)=\($0.1.formEncoded)" }
            .joined(separator: "&")
            .data(using: .utf8)
    }
}

private extension String {
    var formEncoded: String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=?/#[]@!$'()*,:;")
        return addingPercentEncoding(withAllowedCharacters: allowed) ?? self
    }
}
