//
//  MarkdownCopyFormat.swift
//  PolarBear
//

import Foundation

/// The forms a Markdown document can be copied in.
enum MarkdownCopyFormat: CaseIterable, Identifiable {
    /// Formatted text, for Mail, Pages, Notes, Word and web editors.
    case richText
    /// The HTML source, for a CMS or a web page.
    case html
    /// Readable text without any Markdown syntax.
    case plainText

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .richText: "Copy as Rich Text"
        case .html: "Copy as HTML"
        case .plainText: "Copy as Plain Text"
        }
    }

    var symbol: String {
        switch self {
        case .richText: "textformat"
        case .html: "chevron.left.forwardslash.chevron.right"
        case .plainText: "doc.plaintext"
        }
    }
}
