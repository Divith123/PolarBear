//
//  Project+History.swift
//  PolarBear
//

import Foundation

extension Project {
    func historySources() -> [HistorySource] {
        files.map { HistorySource(path: $0.path, text: $0.text) }
    }

    /// ⌘S: writes everything and records a version.
    func saveVersion() async {
        await saveDirtyFiles(triggersBuild: false)
        await history.snapshot(kind: .manual)
    }

    /// Puts the project back the way `version` had it. The state before the restore is
    /// recorded first, so the restore itself can be undone from the history.
    func restore(_ version: VersionRecord) async throws {
        await saveDirtyFiles(triggersBuild: false)
        await history.snapshot(kind: .restore, title: "Before restoring v\(version.number)")

        let texts = await history.texts(of: version)
        for (path, text) in texts {
            if let file = file(atPath: path) {
                file.replaceText(text)
            } else {
                try await createFile(at: path, text: text)
            }
        }
        for file in files where texts[file.path] == nil {
            try trash(file.path)
        }
        editRevision += 1
        await saveDirtyFiles(triggersBuild: true)
        await history.snapshot(kind: .restore, title: "Restored v\(version.number)")
    }
}
