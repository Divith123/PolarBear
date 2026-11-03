//
//  CodeEditor.swift
//  PolarBear
//
//  A real, editable code editor built on TextKit 1 (AppKit): soft wrapping with a hanging
//  indent, a gutter that numbers logical lines and marks problems, a current-line outline,
//  LaTeX syntax highlighting and auto-indent. An editor view is kept alive for the tabs used
//  most recently, so each keeps its scroll position, caret and undo history.
//
//  AppKit is deliberate here: SwiftUI's `TextEditor` cannot provide these features.
//

import SwiftUI

struct CodeEditor: NSViewRepresentable {
    let openFiles: [ProjectFile]
    let activeID: ProjectFile.ID?
    let reveal: RevealRequest?
    let diagnostics: [Diagnostic]
    /// Changes whenever a file's text was replaced from outside the editor.
    let externalRevisions: [Int]
    let onTextChange: (ProjectFile) -> Void
    let onCommandClick: (ProjectFile, Int) -> Void
    let onCaretMove: (ProjectFile, Int) -> Void

    func makeNSView(context: Context) -> EditorContainerView {
        EditorContainerView()
    }

    func updateNSView(_ view: EditorContainerView, context: Context) {
        view.onTextChange = onTextChange
        view.onCommandClick = onCommandClick
        view.onCaretMove = onCaretMove
        view.sync(openFiles: openFiles, activeID: activeID, reveal: reveal, diagnostics: diagnostics)
    }
}
