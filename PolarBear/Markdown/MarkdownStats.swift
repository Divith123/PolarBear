//
//  MarkdownStats.swift
//  PolarBear
//

import Foundation

/// Word and element counts of a Markdown document, in the same shape as the TeX counts. Code
/// blocks and raw HTML are not text; maths does not exist in Markdown.
nonisolated enum MarkdownStats {
    @concurrent
    static func compute(text: String) async -> DocumentStats {
        count(MarkdownDocument(source: text))
    }

    static func count(_ document: MarkdownDocument) -> DocumentStats {
        var stats = DocumentStats()
        visit(document.blocks, into: &stats)
        return stats
    }

    private static func visit(_ blocks: [MarkdownBlock], into stats: inout DocumentStats) {
        for block in blocks {
            switch block {
            case .heading(_, let content):
                stats.headers += 1
                stats.wordsInHeaders += words(in: content)
                stats.figures += images(in: content)
            case .paragraph(let content):
                stats.wordsInText += words(in: content)
                stats.figures += images(in: content)
                stats.inlineMath += inlineMath(in: content)
            case .quote(let inner):
                visit(inner, into: &stats)
            case .list(let list):
                for item in list.items { visit(item.blocks, into: &stats) }
            case .table(let table):
                for cell in table.header + table.rows.flatMap({ $0 }) {
                    stats.wordsInText += words(in: cell)
                    stats.figures += images(in: cell)
                }
            case .definitions(let definitions):
                for definition in definitions {
                    stats.wordsInText += words(in: definition.term) + definition.details.reduce(0) { $0 + words(in: $1) }
                }
            case .math:
                stats.displayedMath += 1
            case .code, .rule, .html:
                continue
            }
        }
    }

    /// The readable text: formulas and picture descriptions are not words.
    private static func text(of inlines: [MarkdownInline]) -> String {
        inlines.map { inline in
            switch inline {
            case .math, .image, .footnote: ""
            case .emphasis(let content), .strong(let content), .strikethrough(let content), .highlight(let content), .link(_, _, let content): text(of: content)
            default: inline.plainText
            }
        }.joined()
    }

    private static func words(in inlines: [MarkdownInline]) -> Int {
        text(of: inlines).split(whereSeparator: \.isWhitespace).count { word in
            word.contains { $0.isLetter || $0.isNumber }
        }
    }

    private static func inlineMath(in inlines: [MarkdownInline]) -> Int {
        inlines.reduce(0) { total, inline in
            switch inline {
            case .math: total + 1
            case .emphasis(let content), .strong(let content), .strikethrough(let content), .highlight(let content), .link(_, _, let content):
                total + inlineMath(in: content)
            default: total
            }
        }
    }

    private static func images(in inlines: [MarkdownInline]) -> Int {
        inlines.reduce(0) { total, inline in
            switch inline {
            case .image: total + 1
            case .emphasis(let content), .strong(let content), .strikethrough(let content), .highlight(let content), .link(_, _, let content):
                total + images(in: content)
            default: total
            }
        }
    }
}
