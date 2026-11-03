//
//  MarkdownBlock.swift
//  PolarBear
//

/// A block of a Markdown document: a heading, a paragraph, a list, a table …
nonisolated indirect enum MarkdownBlock: Equatable, Sendable {
    case heading(level: Int, content: [MarkdownInline])
    case paragraph([MarkdownInline])
    case code(language: String?, text: String)
    case quote([MarkdownBlock])
    case list(List)
    case rule
    case table(Table)
    /// A block of raw HTML, passed through.
    case html(String)
    /// `$$ … $$` on its own lines.
    case math(String)
    case definitions([Definition])

    /// A term and what it means (`Term` / `: meaning`).
    struct Definition: Equatable, Sendable {
        var term: [MarkdownInline]
        var details: [[MarkdownInline]]
    }

    struct List: Equatable, Sendable {
        /// The number of the first item of an ordered list; `nil` for a bulleted one.
        var start: Int?
        /// No blank lines between items: paragraphs are shown without extra spacing.
        var isTight: Bool
        var items: [Item]
    }

    struct Item: Equatable, Sendable {
        var blocks: [MarkdownBlock]
        /// `true` / `false` for a task item (`[x]` / `[ ]`), `nil` for an ordinary one.
        var isChecked: Bool?
    }

    struct Table: Equatable, Sendable {
        enum Alignment: Sendable {
            case none, left, center, right
        }

        var alignments: [Alignment]
        var header: [[MarkdownInline]]
        var rows: [[[MarkdownInline]]]
    }
}
