//
//  HistoryModel.swift
//  PolarBear
//

import Foundation
import Observation

/// A project's versions. A version is recorded when the user saves (⌘S), before and after an
/// accepted agent edit, before a restore, and automatically once editing pauses.
@Observable
final class HistoryModel {
    /// How long editing must pause before a version is recorded on its own.
    private static let idleDelay = Duration.seconds(90)

    /// Newest first.
    private(set) var versions: [VersionRecord] = []
    private(set) var isLoaded = false

    @ObservationIgnored let root: URL
    @ObservationIgnored var sourceProvider: (() -> [HistorySource])?
    @ObservationIgnored private let idleDebouncer = Debouncer()

    init(root: URL) {
        self.root = root
    }

    func load() async {
        versions = await HistoryStore.load(root: root)
        isLoaded = true
        if versions.isEmpty {
            await snapshot(kind: .initial)
        }
    }

    /// Records a version after editing has paused for a while.
    func noteEdit() {
        idleDebouncer.schedule(after: Self.idleDelay) { [weak self] in
            await self?.snapshot(kind: .automatic)
        }
    }

    /// Records the project as it is now; does nothing when it matches the newest version.
    @discardableResult
    func snapshot(kind: VersionRecord.Kind, title: String? = nil) async -> VersionRecord? {
        guard let sources = sourceProvider?() else { return nil }
        guard let version = await HistoryStore.record(
            sources: sources, previous: versions.first, kind: kind, title: title, root: root
        ) else { return nil }
        versions.insert(version, at: 0)
        await HistoryStore.save(versions, root: root)
        return version
    }

    /// What changed in `version` compared with the one before it.
    func changes(of version: VersionRecord) async -> [FileChange] {
        let index = versions.firstIndex { $0.id == version.id }
        let previous = index.flatMap { versions.indices.contains($0 + 1) ? versions[$0 + 1] : nil }
        let new = await HistoryStore.texts(of: version.manifest, root: root)
        let old = await HistoryStore.texts(of: previous?.manifest ?? [:], root: root)
        return FileChange.changes(old: old, new: new)
    }

    func texts(of version: VersionRecord) async -> [String: String] {
        await HistoryStore.texts(of: version.manifest, root: root)
    }
}
