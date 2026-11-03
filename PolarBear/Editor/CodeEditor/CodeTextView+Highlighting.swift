//
//  CodeTextView+Highlighting.swift
//  PolarBear
//

import SwiftUI

/// Syntax colouring that only touches what a change can affect: the edited lines, plus the
/// lines after them until the line state (math `$…$`, `\[…\]` in TeX; a code fence in Markdown) matches what it was before. Typing
/// in a long document therefore costs the same as typing in a short one.
extension CodeTextView {
    /// Colours the whole document and rebuilds the per-line state.
    func highlightEverything() {
        pendingEdit = nil
        guard let storage = textStorage else { return }
        if hasMarkedText() {
            needsFullHighlight = true // Colour after the input method commits (see `unmarkText`).
            return
        }
        needsFullHighlight = false

        let total = storage.length
        endStates = []
        typingAttributes = baseAttributes(indent: 0)
        guard total > 0 else {
            endStates = [false]
            return
        }

        var inMath = false
        var location = 0
        storage.beginEditing()
        for line in storage.string.split(separator: "\n", omittingEmptySubsequences: false) {
            colorLine(String(line), at: location, total: total, inMath: &inMath, in: storage)
            endStates.append(inMath)
            location += line.utf16.count + 1
        }
        storage.endEditing()
    }

    /// Called after every text change.
    func applyHighlightingAfterEdit() {
        guard let edit = pendingEdit, !needsFullHighlight, !endStates.isEmpty, !hasMarkedText(),
              let storage = textStorage else {
            highlightEverything()
            return
        }
        pendingEdit = nil

        let oldCount = endStates.count
        let newCount = lineStarts.count
        let delta = newCount - oldCount
        let first = max(lineNumber(at: edit.location) - 1, 0)
        let last = max(lineNumber(at: edit.location + edit.length) - 1, first)
        guard first < newCount, first <= oldCount else {
            highlightEverything()
            return
        }

        let text = storage.string as NSString
        let total = text.length
        var inMath = first == 0 ? false : endStates[first - 1]
        var updated = Array(endStates[0..<first])

        storage.beginEditing()
        var index = first
        while index < newCount {
            let start = lineStarts[index]
            let end = index + 1 < newCount ? lineStarts[index + 1] - 1 : total
            let line = text.substring(with: NSRange(location: start, length: max(end - start, 0)))
            colorLine(line, at: start, total: total, inMath: &inMath, in: storage)
            updated.append(inMath)

            if index >= last {
                let oldIndex = index - delta
                if oldIndex >= 0, oldIndex < oldCount, endStates[oldIndex] == inMath {
                    updated += endStates[(oldIndex + 1)...]
                    break
                }
            }
            index += 1
        }
        storage.endEditing()

        if updated.count == newCount {
            endStates = updated
        } else {
            highlightEverything()
        }
    }

    /// Gives one line its base style, its hanging indent and its token colours.
    private func colorLine(_ line: String, at start: Int, total: Int, inMath: inout Bool, in storage: NSTextStorage) {
        let range = NSRange(location: start, length: min(line.utf16.count + 1, total - start))
        guard range.length > 0 else { return }

        storage.setAttributes(baseAttributes(indent: 0), range: range)
        let indent = line.prefix(while: { $0 == " " }).count
        if indent > 0 {
            storage.addAttribute(.paragraphStyle, value: paragraphStyle(indent: indent), range: range)
        }
        let tokens: [LaTeXToken]
        switch language {
        case .tex: tokens = LaTeXHighlighter.tokens(in: line, inMath: &inMath)
        case .markdown: tokens = MarkdownHighlighter.tokens(in: line, inFence: &inMath)
        case .plain: return
        }

        var cursor = start
        for token in tokens {
            if token.kind != .text, cursor + token.length <= storage.length {
                storage.addAttribute(
                    .foregroundColor,
                    value: SyntaxPalette.color(for: token.kind),
                    range: NSRange(location: cursor, length: token.length)
                )
            }
            cursor += token.length
        }
    }
}
