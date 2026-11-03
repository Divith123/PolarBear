//
//  ToolDownloader.swift
//  PolarBear
//

import CryptoKit
import Foundation

/// Downloads a file with progress, and checks it against a SHA-256.
nonisolated enum ToolDownloader {
    /// Downloads `url` into a new temporary folder (named like the file) and returns the file.
    @concurrent
    static func download(_ url: URL, named name: String, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        let delegate = Delegate(name: name, progress: progress)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieAcceptPolicy = .never
        configuration.timeoutIntervalForRequest = 30
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                delegate.continuation = continuation
                var request = URLRequest(url: url)
                request.setValue("PolarBear", forHTTPHeaderField: "User-Agent")
                let task = session.downloadTask(with: request)
                delegate.task = task
                task.resume()
            }
        } onCancel: {
            delegate.cancel()
        }
    }

    /// The SHA-256 of a file, in lower-case hexadecimal, read in pieces.
    @concurrent
    static func sha256(of file: URL) async throws -> String {
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            try Task.checkCancellation()
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { ($0 < 16 ? "0" : "") + String($0, radix: 16) }.joined()
    }

    // MARK: Delegate

    private final class Delegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
        let name: String
        let progress: @Sendable (Double) -> Void
        var continuation: CheckedContinuation<URL, Error>?
        var task: URLSessionDownloadTask?
        private let lock = NSLock()
        private var finished = false

        init(name: String, progress: @escaping @Sendable (Double) -> Void) {
            self.name = name
            self.progress = progress
        }

        func cancel() {
            task?.cancel()
        }

        private func finish(_ result: Result<URL, Error>) {
            lock.lock()
            defer { lock.unlock() }
            guard !finished else { return }
            finished = true
            continuation?.resume(with: result)
            continuation = nil
        }

        func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
            guard totalBytesExpectedToWrite > 0 else { return }
            progress(min(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite), 1))
        }

        func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
            guard (downloadTask.response as? HTTPURLResponse)?.statusCode == 200 else {
                finish(.failure(ToolInstallError.badDownload("HTTP \((downloadTask.response as? HTTPURLResponse)?.statusCode ?? 0)")))
                return
            }
            do {
                let folder = FileManager.default.temporaryDirectory.appending(path: "PolarBearDownload-\(UUID().uuidString)", directoryHint: .isDirectory)
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let file = folder.appending(path: name)
                try FileManager.default.moveItem(at: location, to: file)
                finish(.success(file))
            } catch {
                finish(.failure(ToolInstallError.badDownload(error.localizedDescription)))
            }
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            guard let error else { return }
            if (error as? URLError)?.code == .cancelled {
                finish(.failure(CancellationError()))
            } else {
                finish(.failure(ToolInstallError.badDownload(error.localizedDescription)))
            }
        }
    }
}
