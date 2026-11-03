//
//  EditorContainerView.swift
//  PolarBear
//

import SwiftUI

/// Holds the `EditorScrollView`s and shows the one of the active tab. Editors are made when a
/// tab is first shown and the least recently used ones are released, so many open tabs cost
/// little memory; a released editor's caret and scroll position are restored when it returns.
final class EditorContainerView: NSView {
    private static let liveEditorLimit = 6

    var onTextChange: (ProjectFile) -> Void = { _ in }
    var onCommandClick: (ProjectFile, Int) -> Void = { _, _ in }
    var onCaretMove: (ProjectFile, Int) -> Void = { _, _ in }

    private var editors: [ProjectFile.ID: EditorScrollView] = [:]
    /// Most recently shown last.
    private var recency: [ProjectFile.ID] = []
    private var lastActiveID: ProjectFile.ID?
    private var lastRevealToken: UUID?

    override var isFlipped: Bool { true }

    override func layout() {
        super.layout()
        for editor in editors.values {
            editor.frame = bounds
        }
    }

    func sync(
        openFiles: [ProjectFile],
        activeID: ProjectFile.ID?,
        reveal: RevealRequest?,
        diagnostics: [Diagnostic]
    ) {
        removeEditorsForClosedTabs(keeping: Set(openFiles.map(\.id)))

        if let activeID, let file = openFiles.first(where: { $0.id == activeID }) {
            if editors[activeID] == nil { addEditor(for: file) }
            recency.removeAll { $0 == activeID }
            recency.append(activeID)
        }
        releaseLeastRecentlyUsed(keeping: activeID)

        for (id, editor) in editors {
            editor.isHidden = (id != activeID)
            editor.refreshLanguage()
            editor.syncWithFile()
            let markers = Self.markers(for: editor.file.path, in: diagnostics)
            if editor.textView.markers != markers { editor.textView.markers = markers }
        }

        if activeID != lastActiveID {
            lastActiveID = activeID
            if let activeID, let editor = editors[activeID] {
                focus(editor)
            }
        }

        if let reveal, reveal.token != lastRevealToken {
            lastRevealToken = reveal.token
            if let editor = editors[reveal.fileID] {
                editor.textView.reveal(line: reveal.line)
                focus(editor)
            }
        }

        needsLayout = true
    }

    /// Puts the caret on `line` of the file in the active editor (used by sync from the PDF).
    func caretLine(of id: ProjectFile.ID) -> Int? {
        editors[id]?.textView.caretLine
    }

    private func addEditor(for file: ProjectFile) {
        let editor = EditorScrollView(file: file)
        editor.frame = bounds
        editor.onTextChange = { [weak self] file in self?.onTextChange(file) }
        editor.onCaretMove = { [weak self] file, line in self?.onCaretMove(file, line) }
        editor.textView.onCommandClick = { [weak self] line in self?.onCommandClick(file, line) }
        addSubview(editor)
        editors[file.id] = editor
    }

    private func removeEditorsForClosedTabs(keeping openIDs: Set<ProjectFile.ID>) {
        for (id, editor) in editors where !openIDs.contains(id) {
            editor.removeFromSuperview()
            editors[id] = nil
        }
        recency.removeAll { !openIDs.contains($0) }
    }

    private func releaseLeastRecentlyUsed(keeping activeID: ProjectFile.ID?) {
        while editors.count > Self.liveEditorLimit,
              let oldest = recency.first(where: { $0 != activeID && editors[$0] != nil }) {
            editors[oldest]?.captureViewState()
            editors[oldest]?.removeFromSuperview()
            editors[oldest] = nil
            recency.removeAll { $0 == oldest }
        }
    }

    /// The most severe problem per line of `path`.
    private static func markers(for path: String, in diagnostics: [Diagnostic]) -> [Int: Diagnostic.Severity] {
        var result: [Int: Diagnostic.Severity] = [:]
        for diagnostic in diagnostics where diagnostic.file == path {
            guard let line = diagnostic.line else { continue }
            result[line] = max(result[line] ?? .info, diagnostic.severity)
        }
        return result
    }

    /// Moves keyboard focus to the editor once the current SwiftUI update has finished.
    private func focus(_ editor: EditorScrollView) {
        Task { [weak self, weak editor] in
            guard let editor else { return }
            self?.window?.makeFirstResponder(editor.textView)
        }
    }
}
