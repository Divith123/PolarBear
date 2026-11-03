//
//  MarkdownParser.swift
//  PolarBear
//

import Foundation

/// Turns Markdown source into a `MarkdownDocument`: CommonMark's blocks (headings, paragraphs,
/// quotes, lists, code, raw HTML) plus GitHub's tables and task lists. It is written for this
/// app so the preview needs no third-party package.
nonisolated enum MarkdownParser {
    static func parse(_ source: String) -> MarkdownDocument {
        let normalised = source.replacing("\r\n", with: "\n").replacing("\r", with: "\n")
        var lines = normalised.split(separator: "\n", omittingEmptySubsequences: false).map { MarkdownLines.expandTabs(String($0)) }
        lines = removingFrontMatter(from: lines)

        var definitions: [String: MarkdownDocument.LinkDefinition] = [:]
        var footnoteSources: [(id: String, lines: [String])] = []
        lines = removingDefinitions(from: lines, into: &definitions, footnotes: &footnoteSources)

        let context = Context(definitions: definitions, footnoteIDs: Set(footnoteSources.map(\.id)))
        var document = MarkdownDocument(blocks: parseBlocks(lines, context))
        for source in footnoteSources where document.footnotes[source.id] == nil {
            document.footnotes[source.id] = parseBlocks(source.lines, context)
            document.footnoteOrder.append(source.id)
        }
        return document
    }

    struct Context {
        var definitions: [String: MarkdownDocument.LinkDefinition]
        var footnoteIDs: Set<String>
    }

    /// A YAML block (`---` … `---`) at the very top is metadata, not text.
    private static func removingFrontMatter(from lines: [String]) -> [String] {
        guard let opening = lines.firstIndex(where: { !MarkdownLines.isBlank($0) }),
              lines[opening].trimmingCharacters(in: .whitespaces) == "---"
        else { return lines }
        for index in (opening + 1)..<max(lines.count, opening + 1) {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "---" || trimmed == "..." {
                return Array(lines[(index + 1)...])
            }
            // Anything that is not YAML-shaped means this is a horizontal rule, not front matter.
            let isYAML = trimmed.isEmpty || trimmed.hasPrefix("#") || trimmed.hasPrefix("- ") || line.hasPrefix(" ")
                || line.firstMatch(of: /^[A-Za-z0-9_"'.\-][^:]*:(\s|$)/) != nil
            if !isYAML { return lines }
        }
        return lines
    }

    /// `[label]: https://… "title"` and `[^note]: text` lines (outside code) are removed and remembered.
    private static func removingDefinitions(
        from lines: [String],
        into definitions: inout [String: MarkdownDocument.LinkDefinition],
        footnotes: inout [(id: String, lines: [String])]
    ) -> [String] {
        var kept: [String] = []
        var fence: MarkdownLines.Fence?
        var index = 0
        while index < lines.count {
            let line = lines[index]
            index += 1
            if let open = fence {
                if MarkdownLines.closes(line, fence: open) { fence = nil }
                kept.append(line)
                continue
            }
            if let start = MarkdownLines.fenceStart(line) {
                fence = start
                kept.append(line)
                continue
            }
            if let note = line.wholeMatch(of: /^ {0,3}\[\^([^\]\s]+)\]:\s?(.*)$/) {
                var body = [String(note.2)]
                // Indented lines (and blank lines between them) continue the footnote.
                while index < lines.count {
                    let next = lines[index]
                    if MarkdownLines.indent(of: next) >= 4 {
                        body.append(String(next.dropFirst(4)))
                    } else if MarkdownLines.isBlank(next),
                              let after = lines[(index + 1)...].first(where: { !MarkdownLines.isBlank($0) }),
                              MarkdownLines.indent(of: after) >= 4 {
                        body.append("")
                    } else {
                        break
                    }
                    index += 1
                }
                footnotes.append((String(note.1), body))
                continue
            }
            if let match = line.wholeMatch(of: MarkdownLines.definition) {
                let key = MarkdownLines.normalisedLabel(String(match.1))
                if definitions[key] == nil {
                    let title = match.3 ?? match.4 ?? match.5
                    definitions[key] = .init(destination: String(match.2), title: title.map(String.init))
                }
                continue
            }
            kept.append(line)
        }
        return kept
    }

    // MARK: Blocks

    static func parseBlocks(_ lines: [String], _ context: Context) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var index = 0
        let count = lines.count

        while index < count {
            let line = lines[index]
            if MarkdownLines.isBlank(line) {
                index += 1
                continue
            }

            if let fence = MarkdownLines.fenceStart(line) {
                index = parseFence(lines, at: index, fence: fence, into: &blocks)
                continue
            }
            if let heading = MarkdownLines.atxHeading(line) {
                blocks.append(.heading(level: heading.level, content: inlines(heading.text, context)))
                index += 1
                continue
            }
            if MarkdownLines.isThematicBreak(line) {
                blocks.append(.rule)
                index += 1
                continue
            }
            if MarkdownLines.isQuote(line) {
                index = parseQuote(lines, at: index, context, into: &blocks)
                continue
            }
            if MarkdownLines.listMarker(line) != nil {
                index = parseList(lines, at: index, context, into: &blocks)
                continue
            }
            if MarkdownLines.isHTMLBlockStart(line) {
                index = parseHTML(lines, at: index, into: &blocks)
                continue
            }
            if let next = parseMath(lines, at: index, into: &blocks) {
                index = next
                continue
            }
            if MarkdownLines.indent(of: line) >= 4 {
                index = parseIndentedCode(lines, at: index, into: &blocks)
                continue
            }
            if let next = parseTable(lines, at: index, context, into: &blocks) {
                index = next
                continue
            }
            if let next = parseDefinitions(lines, at: index, context, into: &blocks) {
                index = next
                continue
            }
            index = parseParagraph(lines, at: index, context, into: &blocks)
        }
        return blocks
    }

    private static func inlines(_ text: String, _ context: Context) -> [MarkdownInline] {
        MarkdownInlineParser.parse(text, definitions: context.definitions, footnoteIDs: context.footnoteIDs)
    }

    /// `$$ … $$` on its own lines.
    private static func parseMath(_ lines: [String], at start: Int, into blocks: inout [MarkdownBlock]) -> Int? {
        let first = lines[start].trimmingCharacters(in: .whitespaces)
        guard first.hasPrefix("$$") else { return nil }
        let afterOpening = String(first.dropFirst(2))
        if let close = afterOpening.range(of: "$$") {
            guard afterOpening[close.upperBound...].trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
            blocks.append(.math(String(afterOpening[..<close.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)))
            return start + 1
        }
        var content = afterOpening.isEmpty ? [] : [afterOpening]
        var index = start + 1
        while index < lines.count {
            let line = lines[index]
            if let close = line.range(of: "$$") {
                let before = String(line[..<close.lowerBound])
                if !before.trimmingCharacters(in: .whitespaces).isEmpty { content.append(before) }
                blocks.append(.math(content.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)))
                return index + 1
            }
            content.append(line)
            index += 1
        }
        return nil // never closed: an ordinary paragraph
    }

    /// `Term` followed by `: meaning` lines.
    private static func parseDefinitions(_ lines: [String], at start: Int, _ context: Context, into blocks: inout [MarkdownBlock]) -> Int? {
        func isDetail(_ line: String) -> String? {
            guard MarkdownLines.indent(of: line) <= 3 else { return nil }
            let body = MarkdownLines.trimmingLeadingSpaces(line)
            guard body.hasPrefix(":"), body.dropFirst().first == " " else { return nil }
            let text = body.dropFirst().trimmingCharacters(in: .whitespaces)
            return text.isEmpty ? nil : text
        }
        guard start + 1 < lines.count, isDetail(lines[start + 1]) != nil, !startsBlock(lines[start]) else { return nil }

        var definitions: [MarkdownBlock.Definition] = []
        var index = start
        while index + 1 < lines.count, isDetail(lines[index + 1]) != nil {
            let term = inlines(lines[index].trimmingCharacters(in: .whitespaces), context)
            index += 1
            var details: [[MarkdownInline]] = []
            while index < lines.count, let detail = isDetail(lines[index]) {
                details.append(inlines(detail, context))
                index += 1
            }
            definitions.append(MarkdownBlock.Definition(term: term, details: details))
            // Another term may follow, after blank lines.
            var look = index
            while look < lines.count, MarkdownLines.isBlank(lines[look]) { look += 1 }
            if look + 1 < lines.count, isDetail(lines[look + 1]) != nil, isDetail(lines[look]) == nil {
                index = look
            } else {
                break
            }
        }
        blocks.append(.definitions(definitions))
        return index
    }

    private static func parseFence(_ lines: [String], at start: Int, fence: MarkdownLines.Fence, into blocks: inout [MarkdownBlock]) -> Int {
        var content: [String] = []
        var index = start + 1
        while index < lines.count, !MarkdownLines.closes(lines[index], fence: fence) {
            let line = lines[index]
            let removable = min(fence.indent, MarkdownLines.indent(of: line))
            content.append(String(line.dropFirst(removable)))
            index += 1
        }
        let language = fence.info.split(separator: " ").first.map(String.init)
        blocks.append(.code(language: language, text: content.joined(separator: "\n")))
        return min(index + 1, lines.count)
    }

    private static func parseIndentedCode(_ lines: [String], at start: Int, into blocks: inout [MarkdownBlock]) -> Int {
        var content: [String] = []
        var index = start
        while index < lines.count {
            let line = lines[index]
            if MarkdownLines.isBlank(line) {
                content.append(String(line.dropFirst(min(4, line.count))))
            } else if MarkdownLines.indent(of: line) >= 4 {
                content.append(String(line.dropFirst(4)))
            } else {
                break
            }
            index += 1
        }
        while content.last.map(MarkdownLines.isBlank) == true { content.removeLast() }
        blocks.append(.code(language: nil, text: content.joined(separator: "\n")))
        return index
    }

    private static func parseHTML(_ lines: [String], at start: Int, into blocks: inout [MarkdownBlock]) -> Int {
        var content: [String] = []
        var index = start
        let isComment = MarkdownLines.trimmingLeadingSpaces(lines[start]).hasPrefix("<!--")
        while index < lines.count {
            let line = lines[index]
            if isComment {
                content.append(line)
                index += 1
                if line.contains("-->") { break }
            } else {
                if MarkdownLines.isBlank(line) { break }
                content.append(line)
                index += 1
            }
        }
        blocks.append(.html(content.joined(separator: "\n")))
        return index
    }

    private static func parseQuote(_ lines: [String], at start: Int, _ context: Context, into blocks: inout [MarkdownBlock]) -> Int {
        var inner: [String] = []
        var index = start
        while index < lines.count {
            let line = lines[index]
            if MarkdownLines.isQuote(line) {
                inner.append(MarkdownLines.strippingQuoteMarker(line))
            } else if !MarkdownLines.isBlank(line), let last = inner.last, !MarkdownLines.isBlank(last), !startsBlock(line) {
                inner.append(line) // lazy continuation of a paragraph
            } else {
                break
            }
            index += 1
        }
        blocks.append(.quote(parseBlocks(inner, context)))
        return index
    }

    /// A line that cannot continue a paragraph because it starts something else.
    private static func startsBlock(_ line: String) -> Bool {
        if MarkdownLines.fenceStart(line) != nil || MarkdownLines.atxHeading(line) != nil { return true }
        if MarkdownLines.isThematicBreak(line) || MarkdownLines.isQuote(line) { return true }
        if let marker = MarkdownLines.listMarker(line), !marker.content.isEmpty, marker.start == nil || marker.start == 1 { return true }
        return MarkdownLines.isHTMLBlockStart(line)
    }

    // MARK: Lists

    private static func parseList(_ lines: [String], at start: Int, _ context: Context, into blocks: inout [MarkdownBlock]) -> Int {
        guard let first = MarkdownLines.listMarker(lines[start]) else { return start + 1 }
        var items: [MarkdownBlock.Item] = []
        var isLoose = false
        var index = start

        while index < lines.count {
            guard let marker = MarkdownLines.listMarker(lines[index]),
                  marker.character == first.character,
                  !MarkdownLines.isThematicBreak(lines[index])
            else { break }

            var itemLines = [marker.content]
            index += 1
            var pendingBlanks = 0

            while index < lines.count {
                let line = lines[index]
                if MarkdownLines.isBlank(line) {
                    pendingBlanks += 1
                    itemLines.append("")
                    index += 1
                    continue
                }
                if MarkdownLines.indent(of: line) >= marker.contentColumn {
                    itemLines.append(String(line.dropFirst(marker.contentColumn)))
                    pendingBlanks = 0
                    index += 1
                    continue
                }
                if pendingBlanks == 0, !startsBlock(line), MarkdownLines.listMarker(line) == nil {
                    itemLines.append(MarkdownLines.trimmingLeadingSpaces(line)) // lazy continuation
                    index += 1
                    continue
                }
                break
            }

            let trailingBlanks = itemLines.reversed().prefix(while: MarkdownLines.isBlank).count
            itemLines.removeLast(trailingBlanks)
            if trailingBlanks > 0, index < lines.count, let next = MarkdownLines.listMarker(lines[index]), next.character == first.character {
                isLoose = true
            }

            var checked: Bool?
            if let task = itemLines.first?.prefixMatch(of: /\[([ xX])\](?:\s+|$)/) {
                checked = task.1 != " "
                itemLines[0] = String(itemLines[0].dropFirst(task.0.count))
            }

            let itemBlocks = parseBlocks(itemLines, context)
            if itemBlocks.count > 1, hasBlankBetweenBlocks(itemLines) { isLoose = true }
            items.append(MarkdownBlock.Item(blocks: itemBlocks, isChecked: checked))
        }

        blocks.append(.list(MarkdownBlock.List(start: first.start, isTight: !isLoose, items: items)))
        return index
    }

    /// A blank line that is not inside a code fence.
    private static func hasBlankBetweenBlocks(_ lines: [String]) -> Bool {
        var fence: MarkdownLines.Fence?
        for line in lines {
            if let open = fence {
                if MarkdownLines.closes(line, fence: open) { fence = nil }
            } else if let start = MarkdownLines.fenceStart(line) {
                fence = start
            } else if MarkdownLines.isBlank(line) {
                return true
            }
        }
        return false
    }

    // MARK: Tables

    private static func tableCells(_ line: String) -> [String] {
        var body = line.trimmingCharacters(in: .whitespaces)
        if body.hasPrefix("|") { body.removeFirst() }
        if body.hasSuffix("|"), !body.hasSuffix("\\|") { body.removeLast() }
        var cells: [String] = []
        var current = ""
        var escaped = false
        var inCode = false
        for character in body {
            if escaped {
                current.append(character == "|" ? "|" : "\\\(character)")
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else if character == "`" {
                inCode.toggle()
                current.append(character)
            } else if character == "|", !inCode {
                cells.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(character)
            }
        }
        if escaped { current.append("\\") }
        cells.append(current.trimmingCharacters(in: .whitespaces))
        return cells
    }

    private static func alignments(fromDelimiterRow line: String) -> [MarkdownBlock.Table.Alignment]? {
        guard line.contains("-"), line.allSatisfy({ "|:- ".contains($0) }) else { return nil }
        let cells = tableCells(line)
        var result: [MarkdownBlock.Table.Alignment] = []
        for cell in cells {
            guard !cell.isEmpty, cell.contains("-"), cell.allSatisfy({ ":-".contains($0) }) else { return nil }
            switch (cell.hasPrefix(":"), cell.hasSuffix(":")) {
            case (true, true): result.append(.center)
            case (true, false): result.append(.left)
            case (false, true): result.append(.right)
            case (false, false): result.append(.none)
            }
        }
        return result
    }

    /// A pipe table: a header row, a delimiter row, then body rows. Returns the next line to read.
    private static func parseTable(_ lines: [String], at start: Int, _ context: Context, into blocks: inout [MarkdownBlock]) -> Int? {
        guard start + 1 < lines.count, lines[start].contains("|"),
              let alignments = alignments(fromDelimiterRow: lines[start + 1])
        else { return nil }
        let header = tableCells(lines[start])
        guard header.count == alignments.count else { return nil }

        var rows: [[[MarkdownInline]]] = []
        var index = start + 2
        while index < lines.count, !MarkdownLines.isBlank(lines[index]), !startsBlock(lines[index]) {
            var cells = tableCells(lines[index])
            if cells.count > header.count { cells = Array(cells.prefix(header.count)) }
            while cells.count < header.count { cells.append("") }
            rows.append(cells.map { inlines($0, context) })
            index += 1
        }
        blocks.append(.table(MarkdownBlock.Table(
            alignments: alignments,
            header: header.map { inlines($0, context) },
            rows: rows
        )))
        return index
    }

    // MARK: Paragraphs

    private static func parseParagraph(_ lines: [String], at start: Int, _ context: Context, into blocks: inout [MarkdownBlock]) -> Int {
        var text = [MarkdownLines.trimmingLeadingSpaces(lines[start])]
        var index = start + 1
        while index < lines.count {
            let line = lines[index]
            if MarkdownLines.isBlank(line) { break }
            if let level = MarkdownLines.setextLevel(line) {
                blocks.append(.heading(level: level, content: inlines(text.joined(separator: "\n"), context)))
                return index + 1
            }
            if startsBlock(line) { break }
            text.append(MarkdownLines.trimmingLeadingSpaces(line))
            index += 1
        }
        blocks.append(.paragraph(inlines(text.joined(separator: "\n"), context)))
        return index
    }
}
