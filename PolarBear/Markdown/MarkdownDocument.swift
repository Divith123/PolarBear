//
//  MarkdownDocument.swift
//  PolarBear
//

import Foundation

/// A parsed Markdown file.
nonisolated struct MarkdownDocument: Equatable, Sendable {
    struct LinkDefinition: Equatable, Sendable {
        var destination: String
        var title: String?
    }

    var blocks: [MarkdownBlock]
    /// The text of each footnote by name, and the order they were defined in.
    var footnotes: [String: [MarkdownBlock]] = [:]
    var footnoteOrder: [String] = []

    init(source: String) {
        self = MarkdownParser.parse(source)
    }

    init(blocks: [MarkdownBlock]) {
        self.blocks = blocks
    }

    /// The first top-level heading, for the title of a page.
    var title: String? {
        for case .heading(_, let content) in blocks {
            return MarkdownInline.plainText(of: content)
        }
        return nil
    }
}
