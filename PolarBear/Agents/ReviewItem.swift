//
//  ReviewItem.swift
//  PolarBear
//

import Foundation

/// One file of an agent's proposal, and what has been decided about its hunks so far.
struct ReviewItem: Identifiable {
    let change: FileChange
    var keptHunks: Set<Int> = []
    var undoneHunks: Set<Int> = []
    /// The file changed after the agent started, so its hunks can no longer be applied safely.
    var isStale = false

    var id: String { change.path }

    var pendingHunks: [TextDiff.Hunk] {
        change.hunks.filter { !keptHunks.contains($0.id) && !undoneHunks.contains($0.id) }
    }

    /// Edit indices (in `TextDiff.edits`) of the hunks that were kept.
    var keptEdits: Set<Int> {
        Set(change.hunks.filter { keptHunks.contains($0.id) }.flatMap(\.editIndices))
    }
}
