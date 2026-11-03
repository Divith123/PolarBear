//
//  MarkdownPlainTextWriter.swift
//  PolarBear
//

import Foundation

/// Writes a document as readable plain text: no Markdown syntax, lists with bullets and
/// numbers, tables as tab-separated rows (which paste neatly into a spreadsheet).
nonisolated enum MarkdownPlainTextWriter {
    static func write(_ document: MarkdownDocument) -> String {
        var output = blocks(document.blocks, indent: "").trimmingCharacters(in: .whitespacesAndNewlines)
        for name in document.footnoteOrder {
            let note = blocks(document.footnotes[name] ?? [], indent: "").trimmingCharacters(in: .whitespacesAndNewlines)
            output += "\n\n[\(name)] " + note
        }
        return output + "\n"
    }

    private static func blocks(_ elements: [MarkdownBlock], indent: String) -> String {
        var parts: [String] = []
        for block in elements {
            switch block {
            case .heading(_, let content), .paragraph(let content):
                parts.append(prefixed(text(content), with: indent))
            case .code(_, let code):
                parts.append(prefixed(code, with: indent))
            case .quote(let inner):
                parts.append(blocks(inner, indent: indent + "> ").trimmingCharacters(in: .newlines))
            case .rule:
                parts.append(indent + "* * *")
            case .html:
                continue
            case .math(let formula):
                parts.append(prefixed(formula, with: indent))
            case .definitions(let definitions):
                let lines = definitions.flatMap { definition in
                    [text(definition.term)] + definition.details.map { "    " + text($0) }
                }
                parts.append(prefixed(lines.joined(separator: "\n"), with: indent))
            case .list(let list):
                parts.append(self.list(list, indent: indent))
            case .table(let table):
                var rows = [table.header.map(text).joined(separator: "\t")]
                rows += table.rows.map { $0.map(text).joined(separator: "\t") }
                parts.append(prefixed(rows.joined(separator: "\n"), with: indent))
            }
        }
        return parts.joined(separator: "\n\n") + "\n"
    }

    private static func list(_ list: MarkdownBlock.List, indent: String) -> String {
        var lines: [String] = []
        for (offset, item) in list.items.enumerated() {
            var marker = list.start.map { "\($0 + offset). " } ?? "• "
            if let checked = item.isChecked { marker = checked ? "☑ " : "☐ " }
            let body = blocks(item.blocks, indent: "").trimmingCharacters(in: .newlines)
            let hanging = String(repeating: " ", count: marker.count)
            let rows = body.split(separator: "\n", omittingEmptySubsequences: false).enumerated().map { row, line in
                indent + (row == 0 ? marker : (line.isEmpty ? "" : hanging)) + line
            }
            lines.append(rows.joined(separator: "\n"))
        }
        return lines.joined(separator: "\n")
    }

    private static func prefixed(_ text: String, with prefix: String) -> String {
        guard !prefix.isEmpty else { return text }
        return text.split(separator: "\n", omittingEmptySubsequences: false).map { prefix + $0 }.joined(separator: "\n")
    }

    private static func text(_ inlines: [MarkdownInline]) -> String {
        var output = ""
        for inline in inlines {
            switch inline {
            case .link(let destination, _, let content):
                let label = text(content)
                output += (label == destination || label.isEmpty) ? destination : "\(label) (\(destination))"
            case .emphasis(let content), .strong(let content), .strikethrough(let content), .highlight(let content):
                output += text(content)
            case .footnote(let name):
                output += "[\(name)]"
            default:
                output += inline.plainText
            }
        }
        return output
    }
}
