//
//  TextDiff.swift
//  PolarBear
//

import Foundation

/// A line-based diff: which lines of `old` became which lines of `new`, grouped into hunks
/// with surrounding context. The same engine drives version history and the review of agent
/// edits, where each hunk can be kept or undone on its own.
nonisolated enum TextDiff {
    struct Line: Hashable, Sendable {
        enum Kind: Sendable {
            case context
            case added
            case removed
        }

        var kind: Kind
        var text: String
        var oldNumber: Int?
        var newNumber: Int?
    }

    /// A run of changed lines: `oldRange` of the old text became `newRange` of the new text
    /// (both are line indices, zero-based, half-open).
    struct Edit: Hashable, Sendable {
        var oldRange: Range<Int>
        var newRange: Range<Int>
    }

    /// Edits close enough to share context are shown (and kept or undone) together.
    struct Hunk: Identifiable, Hashable, Sendable {
        var id: Int
        var editIndices: [Int]
        var lines: [Line]
        var added: Int
        var removed: Int
    }

    static func lines(of text: String) -> [String] {
        text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    // MARK: Edits

    static func edits(old: [String], new: [String]) -> [Edit] {
        let difference = new.difference(from: old)
        var removedOld: Set<Int> = []
        var insertedNew: Set<Int> = []
        for change in difference {
            switch change {
            case .remove(let offset, _, _): removedOld.insert(offset)
            case .insert(let offset, _, _): insertedNew.insert(offset)
            }
        }

        var edits: [Edit] = []
        var i = 0
        var j = 0
        while i < old.count || j < new.count {
            if removedOld.contains(i) || insertedNew.contains(j) {
                let oldStart = i
                let newStart = j
                while i < old.count, removedOld.contains(i) { i += 1 }
                while j < new.count, insertedNew.contains(j) { j += 1 }
                edits.append(Edit(oldRange: oldStart..<i, newRange: newStart..<j))
            } else {
                i += 1
                j += 1
            }
        }
        return edits
    }

    static func counts(old: String, new: String) -> (added: Int, removed: Int) {
        let edits = edits(old: lines(of: old), new: lines(of: new))
        return (edits.reduce(0) { $0 + $1.newRange.count }, edits.reduce(0) { $0 + $1.oldRange.count })
    }

    // MARK: Hunks

    static func hunks(old oldText: String, new newText: String, context: Int = 3) -> [Hunk] {
        let old = lines(of: oldText)
        let new = lines(of: newText)
        return hunks(old: old, new: new, edits: edits(old: old, new: new), context: context)
    }

    static func hunks(old: [String], new: [String], edits: [Edit], context: Int = 3) -> [Hunk] {
        guard !edits.isEmpty else { return [] }

        // Group edits whose gap is small enough for their context to touch.
        var groups: [[Int]] = [[0]]
        for index in 1..<edits.count {
            let gap = edits[index].oldRange.lowerBound - edits[index - 1].oldRange.upperBound
            if gap <= 2 * context {
                groups[groups.count - 1].append(index)
            } else {
                groups.append([index])
            }
        }

        // How far line numbers have drifted before each edit.
        var offsets: [Int] = []
        var running = 0
        for edit in edits {
            offsets.append(running)
            running += edit.newRange.count - edit.oldRange.count
        }

        return groups.enumerated().map { id, indices in
            var lines: [Line] = []
            var added = 0
            var removed = 0
            let first = edits[indices[0]]
            let last = edits[indices[indices.count - 1]]
            var cursor = max(first.oldRange.lowerBound - context, 0)
            let end = min(last.oldRange.upperBound + context, old.count)

            func appendContext(upTo limit: Int, offset: Int) {
                while cursor < limit {
                    lines.append(Line(kind: .context, text: old[cursor], oldNumber: cursor + 1, newNumber: cursor + offset + 1))
                    cursor += 1
                }
            }

            for index in indices {
                let edit = edits[index]
                appendContext(upTo: edit.oldRange.lowerBound, offset: offsets[index])
                for k in edit.oldRange {
                    lines.append(Line(kind: .removed, text: old[k], oldNumber: k + 1, newNumber: nil))
                    removed += 1
                }
                for k in edit.newRange {
                    lines.append(Line(kind: .added, text: new[k], oldNumber: nil, newNumber: k + 1))
                    added += 1
                }
                cursor = edit.oldRange.upperBound
            }
            let finalOffset = offsets[indices[indices.count - 1]]
                + last.newRange.count - last.oldRange.count
            appendContext(upTo: end, offset: finalOffset)
            return Hunk(id: id, editIndices: indices, lines: lines, added: added, removed: removed)
        }
    }

    // MARK: Merging

    /// `old` with only the edits for which `keep` returns `true` applied. Keeping all of them
    /// gives `new`; keeping none gives `old`.
    static func merge(old oldText: String, new newText: String, keep: (Int) -> Bool) -> String {
        let old = lines(of: oldText)
        let new = lines(of: newText)
        let edits = edits(old: old, new: new)

        var result: [String] = []
        var cursor = 0
        for (index, edit) in edits.enumerated() {
            result += old[cursor..<edit.oldRange.lowerBound]
            result += keep(index) ? Array(new[edit.newRange]) : Array(old[edit.oldRange])
            cursor = edit.oldRange.upperBound
        }
        result += old[cursor...]
        return result.joined(separator: "\n")
    }
}
