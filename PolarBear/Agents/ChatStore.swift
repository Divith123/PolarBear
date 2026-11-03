//
//  ChatStore.swift
//  PolarBear
//

import Foundation
import os

/// Reads and writes chat sessions, one JSON file each.
nonisolated enum ChatStore {
    private static func url(for id: UUID, root: URL) -> URL {
        ProjectPaths.chatsDirectory(in: root).appending(path: "\(id.uuidString).json")
    }

    /// Newest first.
    @concurrent
    static func load(root: URL) async -> [ChatSession] {
        let directory = ProjectPaths.chatsDirectory(in: root)
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path(percentEncoded: false))) ?? []
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return names.filter { $0.hasSuffix(".json") }
            .compactMap { try? decoder.decode(ChatSession.self, from: Data(contentsOf: directory.appending(path: $0))) }
            .sorted { $0.created > $1.created }
    }

    @concurrent
    static func save(_ session: ChatSession, root: URL) async {
        ProjectPaths.prepareMetadata(in: root)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            try FileManager.default.createDirectory(at: ProjectPaths.chatsDirectory(in: root), withIntermediateDirectories: true)
            try encoder.encode(session).write(to: url(for: session.id, root: root), options: .atomic)
        } catch {
            Log.agents.error("Could not save a chat: \(error.localizedDescription, privacy: .public)")
        }
    }

    @concurrent
    static func delete(_ session: ChatSession, root: URL) async {
        try? FileManager.default.removeItem(at: url(for: session.id, root: root))
    }
}
