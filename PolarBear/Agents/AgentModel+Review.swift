//
//  AgentModel+Review.swift
//  PolarBear
//

import Foundation

/// Keeping and undoing the hunks of an agent's proposal. A hunk only reaches the project when
/// it is kept; a version is recorded before the first one is applied, so every keep can be reverted.
extension AgentModel {
    func keep(_ hunk: TextDiff.Hunk, in path: String) {
        Task { await decide(hunks: [(path, hunk)], keep: true) }
    }

    func undo(_ hunk: TextDiff.Hunk, in path: String) {
        Task { await decide(hunks: [(path, hunk)], keep: false) }
    }

    func keepAll() {
        guard let review else { return }
        let pending = review.items.filter { !$0.isStale }.flatMap { item in item.pendingHunks.map { (item.id, $0) } }
        Task { await decide(hunks: pending, keep: true) }
    }

    func undoAll() {
        guard let review else { return }
        let pending = review.items.flatMap { item in item.pendingHunks.map { (item.id, $0) } }
        Task { await decide(hunks: pending, keep: false) }
    }

    // MARK: Applying

    private func decide(hunks: [(path: String, hunk: TextDiff.Hunk)], keep: Bool) async {
        guard let review, let project else { return }

        if keep {
            await project.history.snapshot(kind: .agent, title: "Before agent edit")
            for path in Set(hunks.map(\.path)) {
                await apply(hunks.filter { $0.path == path }.map(\.hunk), to: path, review: review, project: project)
            }
        } else {
            for (path, hunk) in hunks {
                guard let index = review.items.firstIndex(where: { $0.id == path }) else { continue }
                review.items[index].undoneHunks.insert(hunk.id)
            }
        }
        await finishIfDecided(review, project: project)
    }

    private func apply(_ hunks: [TextDiff.Hunk], to path: String, review: AgentReview, project: Project) async {
        guard let index = review.items.firstIndex(where: { $0.id == path }) else { return }
        let item = review.items[index]
        let change = item.change

        // What the file should look like now, given the hunks kept earlier.
        let expected = TextDiff.merge(old: change.old, new: change.new) { item.keptEdits.contains($0) }
        var edits = item.keptEdits
        for hunk in hunks { edits.formUnion(hunk.editIndices) }
        let result = TextDiff.merge(old: change.old, new: change.new) { edits.contains($0) }

        do {
            switch change.status {
            case .modified:
                guard let file = project.file(atPath: path), file.text == expected else {
                    review.items[index].isStale = true
                    return
                }
                file.replaceText(result)
            case .added:
                if let file = project.file(atPath: path) {
                    guard file.text == expected else {
                        review.items[index].isStale = true
                        return
                    }
                    file.replaceText(result)
                } else {
                    try await project.createFile(at: path, text: result)
                }
            case .deleted:
                guard let file = project.file(atPath: path), file.text == expected else {
                    review.items[index].isStale = true
                    return
                }
                let allKept = change.hunks.allSatisfy { edits.isSuperset(of: Set($0.editIndices)) }
                if allKept {
                    try project.trash(path)
                } else {
                    file.replaceText(result)
                }
            }
            for hunk in hunks { review.items[index].keptHunks.insert(hunk.id) }
            project.editRevision += 1
        } catch {
            append(.error, error.localizedDescription)
        }
    }

    private func finishIfDecided(_ review: AgentReview, project: Project) async {
        guard review.isFinished else { return }
        let kept = review.keptCount
        self.review = nil
        guard kept > 0 else {
            append(.activity, String(localized: "Discarded the proposed changes."))
            return
        }
        append(.activity, String(localized: "Kept ^[\(kept) change](inflect: true)."))
        await project.saveDirtyFiles(triggersBuild: false)
        await project.history.snapshot(kind: .agent, title: "Agent: \(review.prompt.prefix(40))")
        project.compile()
    }
}
