//
//  MarkdownInline.swift
//  PolarBear
//

/// Text-level Markdown: emphasis, code spans, links, images and breaks.
nonisolated indirect enum MarkdownInline: Equatable, Sendable {
    case text(String)
    case code(String)
    case emphasis([MarkdownInline])
    case strong([MarkdownInline])
    case strikethrough([MarkdownInline])
    /// `==marked==`
    case highlight([MarkdownInline])
    case link(destination: String, title: String?, content: [MarkdownInline])
    case image(source: String, title: String?, alt: String)
    case softBreak
    case lineBreak
    /// An HTML tag written in the Markdown (`<kbd>`, `<br>`), passed through.
    case html(String)
    /// `$x^2$`: kept as written, set apart from the text around it (no maths typesetting yet).
    case math(String)
    /// `[^note]`: a reference to a footnote.
    case footnote(String)

    /// The text without any formatting.
    var plainText: String {
        switch self {
        case .text(let text), .code(let text), .math(let text): text
        case .emphasis(let content), .strong(let content), .strikethrough(let content), .highlight(let content): Self.plainText(of: content)
        case .link(_, _, let content): Self.plainText(of: content)
        case .image(_, _, let alt): alt
        case .softBreak: " "
        case .lineBreak: "\n"
        case .html, .footnote: ""
        }
    }

    static func plainText(of inlines: [MarkdownInline]) -> String {
        inlines.map(\.plainText).joined()
    }
}
