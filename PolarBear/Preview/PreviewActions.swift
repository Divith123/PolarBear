//
//  PreviewActions.swift
//  PolarBear
//

import Foundation

/// What the preview can ask its surroundings to do. The workspace fills in all of them; a
/// preview in its own window, which has no editor, leaves the editor-related ones empty.
struct PreviewActions {
    /// Scroll the PDF to the line the editor's caret is on.
    var goToPDF: (() -> Void)?
    /// A ⌘-click on page `pageIndex` at `point`: open the matching source line.
    var jumpToSource: ((_ pageIndex: Int, _ point: CGPoint) -> Void)?
    /// Open the file and line of a diagnostic.
    var openDiagnostic: ((Diagnostic) -> Void)?
    var exportPDF: () -> Void
    /// Sends the build's errors and warnings to the assistant; `nil` in a window without a conversation.
    var fixWithAI: FixWithAIAction?
    /// Set in a Markdown project: the download menu replaces the single PDF button.
    var markdown: MarkdownActions?
    var openInWindow: (() -> Void)?
    var openFullScreen: (() -> Void)?
    var undo: (() -> Void)?
    var redo: (() -> Void)?
}
