//
//  MarkdownActions.swift
//  PolarBear
//

import Foundation

/// What the menus of a Markdown project can do with the document being edited.
struct MarkdownActions {
    var downloadMarkdown: () -> Void
    var downloadPDF: () -> Void
    var copy: (MarkdownCopyFormat) -> Void
}
