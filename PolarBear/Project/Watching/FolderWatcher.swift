//
//  FolderWatcher.swift
//  PolarBear
//
//  Reports changes inside a project folder using FSEvents — the system pushes events, nothing
//  is polled, so an idle project costs no CPU. FSEvents delivers on a dispatch queue; this is
//  the only place in the app that touches one.
//

import CoreServices
import Foundation
import os

nonisolated final class FolderWatcher: @unchecked Sendable {
    /// Yields (at most one pending value) whenever something inside the folder changed.
    let changes: AsyncStream<Void>

    private let continuation: AsyncStream<Void>.Continuation
    private let queue = DispatchQueue(label: "com.hustleronduty.PolarBear.folder-watcher")
    private var stream: FSEventStreamRef?

    init(root: URL, latency: TimeInterval = 0.3) {
        let (changes, continuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        self.changes = changes
        self.continuation = continuation

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let callback: FSEventStreamCallback = { _, info, count, paths, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<FolderWatcher>.fromOpaque(info).takeUnretainedValue()
            let list = unsafeBitCast(paths, to: NSArray.self) as? [String] ?? []
            watcher.handle(Array(list.prefix(count)))
        }
        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagNoDefer
        )
        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            [root.path(percentEncoded: false)] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            latency,
            flags
        ) else {
            Log.watcher.error("Could not watch \(root.path(percentEncoded: false), privacy: .public)")
            return
        }
        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
    }

    deinit {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        continuation.finish()
    }

    /// Ignores the app's own metadata folder and version-control internals.
    private func handle(_ paths: [String]) {
        let relevant = paths.contains { path in
            !path.contains("/\(ProjectPaths.metadataFolderName)/") && !path.contains("/.git/")
                && !path.hasSuffix("/\(ProjectPaths.metadataFolderName)")
        }
        if relevant { continuation.yield(()) }
    }
}
