//
//  MarkdownDocument+Images.swift
//  PolarBear
//

import Foundation

nonisolated extension MarkdownDocument {
    /// The `http(s)` addresses of the images in the document, in order and without repeats.
    var remoteImageSources: [String] {
        var found: [String] = []
        var seen: Set<String> = []

        func visit(_ inlines: [MarkdownInline]) {
            for inline in inlines {
                switch inline {
                case .image(let source, _, _):
                    let lowered = source.lowercased()
                    if (lowered.hasPrefix("http://") || lowered.hasPrefix("https://")), seen.insert(source).inserted {
                        found.append(source)
                    }
                case .emphasis(let content), .strong(let content), .strikethrough(let content), .highlight(let content), .link(_, _, let content):
                    visit(content)
                default:
                    break
                }
            }
        }

        func visit(_ blocks: [MarkdownBlock]) {
            for block in blocks {
                switch block {
                case .heading(_, let content), .paragraph(let content): visit(content)
                case .quote(let inner): visit(inner)
                case .list(let list): for item in list.items { visit(item.blocks) }
                case .table(let table):
                    for cell in table.header + table.rows.flatMap({ $0 }) { visit(cell) }
                case .definitions(let definitions):
                    for definition in definitions {
                        visit(definition.term)
                        for detail in definition.details { visit(detail) }
                    }
                case .code, .rule, .html, .math: break
                }
            }
        }

        visit(blocks)
        for name in footnoteOrder { visit(footnotes[name] ?? []) }
        return found
    }
}
