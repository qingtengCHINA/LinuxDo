//
//  ImageLoader.swift
//  LinuxDo
//
//  图片加载器：URLCache + FileManager 磁盘缓存
//

import Foundation
import SwiftUI

@MainActor
final class ImageLoader {
    static let shared = ImageLoader()
    private let memoryCache = NSCache<NSURL, NSData>()
    private lazy var diskCacheDir: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ImageCache")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()
    private var tasks: [URL: Task<Data?, Never>] = [:]

    private init() {
        memoryCache.totalCostLimit = AppConstants.imageCacheMemoryLimit
    }

    func load(url: URL) async -> Data? {
        if let existing = tasks[url] {
            return await existing.value
        }
        let task = Task<Data?, Never> { [weak self] in
            guard let self else { return nil }
            return await self._load(url: url)
        }
        tasks[url] = task
        defer { tasks.removeValue(forKey: url) }
        return await task.value
    }

    func prefetch(url: URL) {
        Task { let _ = await load(url: url) }
    }

    // MARK: - Private

    private func _load(url: URL) async -> Data? {
        if let mem = memoryCache.object(forKey: url as NSURL) {
            return mem as Data
        }
        if let disk = diskData(for: url) {
            memoryCache.setObject(disk as NSData, forKey: url as NSURL)
            return disk
        }
        guard let data = try? await download(url: url) else { return nil }
        memoryCache.setObject(data as NSData, forKey: url as NSURL)
        saveToDisk(data, for: url)
        return data
    }

    private func download(url: URL) async throws -> Data {
        var req = URLRequest(url: url)
        req.setValue(AppConstants.userAgent, forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 30
        let (data, _) = try await URLSession.shared.data(for: req)
        return data
    }

    private func diskData(for url: URL) -> Data? {
        let fileURL = diskFileURL(for: url)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        if let created = attrs?[.creationDate] as? Date,
           Date().timeIntervalSince(created) > AppConstants.imageCacheExpiration {
            try? FileManager.default.removeItem(at: fileURL)
            return nil
        }
        return try? Data(contentsOf: fileURL)
    }

    private func saveToDisk(_ data: Data, for url: URL) {
        try? data.write(to: diskFileURL(for: url), options: .atomic)
    }

    private func diskFileURL(for url: URL) -> URL {
        let hash = url.absoluteString.data(using: .utf8)!.base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
        return diskCacheDir.appendingPathComponent(hash)
    }
}
