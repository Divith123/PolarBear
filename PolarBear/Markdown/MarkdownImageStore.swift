//
//  MarkdownImageStore.swift
//  PolarBear
//

import CryptoKit
import Foundation
import os

/// Downloads the remote images of a Markdown document into the project's cache so the page can
/// be printed from local files. The page itself never touches the network. Only `https` is used,
/// no cookies are sent, and a download is limited in time and size.
nonisolated enum MarkdownImageStore {
    struct Result: Sendable {
        /// Remote address → file in the cache.
        var files: [String: URL] = [:]
        /// Remote address → why it could not be loaded.
        var failures: [String: String] = [:]
    }

    private static let maximumImages = 60
    private static let maximumBytes = 20 * 1024 * 1024
    /// A cached copy younger than this is used without asking the server again.
    private static let freshness = TimeInterval(24 * 60 * 60)

    @concurrent
    static func fetch(_ sources: [String], into directory: URL) async -> Result {
        var result = Result()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 25
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }

        await withTaskGroup(of: (String, Swift.Result<URL, FetchError>).self) { group in
            for source in sources.prefix(maximumImages) {
                group.addTask { (source, await load(source, session: session, directory: directory)) }
            }
            for await (source, outcome) in group {
                switch outcome {
                case .success(let file): result.files[source] = file
                case .failure(let error): result.failures[source] = error.message
                }
            }
        }
        for source in sources.dropFirst(maximumImages) {
            result.failures[source] = "Too many remote images in one document."
        }
        return result
    }

    struct FetchError: Error, Sendable {
        var message: String
    }

    private static func load(_ source: String, session: URLSession, directory: URL) async -> Swift.Result<URL, FetchError> {
        guard let url = URL(string: source), url.scheme?.lowercased() == "https", url.host() != nil else {
            return .failure(FetchError(message: source.lowercased().hasPrefix("http://") ? "Only https images are loaded." : "Not a valid address."))
        }
        let stem = SHA256.hash(data: Data(source.utf8)).map { ($0 < 16 ? "0" : "") + String($0, radix: 16) }.joined().prefix(32)
        let fileManager = FileManager.default

        let cached = (try? fileManager.contentsOfDirectory(atPath: directory.path(percentEncoded: false)))?
            .first { $0.hasPrefix(stem + ".") }
            .map { directory.appending(path: $0) }
        if let cached,
           let modified = (try? fileManager.attributesOfItem(atPath: cached.path(percentEncoded: false)))?[.modificationDate] as? Date,
           Date().timeIntervalSince(modified) < freshness {
            return .success(cached)
        }

        var request = URLRequest(url: url)
        request.setValue("PolarBear (Markdown preview)", forHTTPHeaderField: "User-Agent")
        request.setValue("image/*", forHTTPHeaderField: "Accept")
        do {
            let (temporary, response) = try await session.download(for: request)
            defer { try? fileManager.removeItem(at: temporary) }
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                if let cached { return .success(cached) }
                return .failure(FetchError(message: "The server answered \((response as? HTTPURLResponse)?.statusCode ?? 0)."))
            }
            let type = (http.value(forHTTPHeaderField: "Content-Type") ?? "").lowercased()
            guard let fileExtension = fileExtension(forContentType: type, url: url) else {
                return .failure(FetchError(message: "The address is not an image."))
            }
            let size = (try? fileManager.attributesOfItem(atPath: temporary.path(percentEncoded: false)))?[.size] as? Int ?? 0
            guard size > 0, size <= maximumBytes else {
                return .failure(FetchError(message: size == 0 ? "The image is empty." : "The image is larger than 20 MB."))
            }
            let destination = directory.appending(path: "\(stem).\(fileExtension)")
            if fileManager.fileExists(atPath: destination.path(percentEncoded: false)) { try fileManager.removeItem(at: destination) }
            try fileManager.moveItem(at: temporary, to: destination)
            return .success(destination)
        } catch {
            if let cached { return .success(cached) }
            return .failure(FetchError(message: (error as? URLError)?.localizedDescription ?? error.localizedDescription))
        }
    }

    private static func fileExtension(forContentType type: String, url: URL) -> String? {
        if type.hasPrefix("image/png") { return "png" }
        if type.hasPrefix("image/jpeg") || type.hasPrefix("image/jpg") { return "jpg" }
        if type.hasPrefix("image/gif") { return "gif" }
        if type.hasPrefix("image/webp") { return "webp" }
        if type.hasPrefix("image/svg") { return "svg" }
        if type.hasPrefix("image/heic") { return "heic" }
        if type.hasPrefix("image/avif") { return "avif" }
        if type.hasPrefix("image/x-icon") || type.hasPrefix("image/vnd.microsoft.icon") { return "ico" }
        if type.hasPrefix("image/") { return url.pathExtension.isEmpty ? "img" : url.pathExtension }
        return nil
    }
}
