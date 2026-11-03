//
//  AgentReview.swift
//  PolarBear
//

import Foundation
import Observation

/// An agent's proposal: the changes it made in its working copy, waiting for the user to keep
/// or undo each hunk.
@Observable
final class AgentReview {
    let agent: AgentKind
    let prompt: String
    var items: [ReviewItem]

    init(agent: AgentKind, prompt: String, changes: [FileChange]) {
        self.agent = agent
        self.prompt = prompt
        self.items = changes.map { ReviewItem(change: $0) }
    }

    var pendingCount: Int {
        items.reduce(0) { $0 + ($1.isStale ? 0 : $1.pendingHunks.count) }
    }

    var keptCount: Int {
        items.reduce(0) { $0 + $1.keptHunks.count }
    }

    var isFinished: Bool {
        pendingCount == 0
    }

    var added: Int {
        items.reduce(0) { $0 + $1.change.added }
    }

    var removed: Int {
        items.reduce(0) { $0 + $1.change.removed }
    }
}
