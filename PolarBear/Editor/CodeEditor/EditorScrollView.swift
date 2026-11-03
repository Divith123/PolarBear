//
//  EditorScrollView.swift
//  PolarBear
//

import SwiftUI

/// Scroll view around one file's `CodeTextView`.
final class EditorScrollView: NSScrollView, NSTextViewDelegate {
    let file: ProjectFile
    let textView = CodeTextView()
    var onTextChange: (ProjectFile) -> Void = { _ in }
    var onCaretMove: (ProjectFile, Int) -> Void = { _, _ in }

    private var appliedRevision: Int
    private var isApplyingExternalChange = false

    init(file: ProjectFile) {
        self.file = file
        self.appliedRevision = file.externalRevision
        super.init(frame: .zero)

        drawsBackground = false
        contentView.drawsBackground = false
        borderType = .noBorder
        hasVerticalScroller = true
        hasHorizontalScroller = false
        autohidesScrollers = true
        scrollerStyle = .overlay
        scrollerKnobStyle = .default
        automaticallyAdjustsContentInsets = false
        contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: CodeMetrics.bottomInset, right: 0)

        documentView = textView
        textView.delegate = self
        textView.load(text: file.text, language: file.language)
        restoreViewState()
    }

    required init?(coder: NSCoder) {
        fatalError("EditorScrollView is created in code only")
    }

    override func tile() {
        super.tile()
        textView.minSize = NSSize(width: 0, height: contentSize.height)
    }

    /// Re-highlights when a rename changed the file's language.
    func refreshLanguage() {
        textView.setLanguage(file.language)
    }

    /// Shows text that was changed outside this editor (another program, an agent, a restore).
    func syncWithFile() {
        guard file.externalRevision != appliedRevision else { return }
        appliedRevision = file.externalRevision
        isApplyingExternalChange = true
        textView.replaceContents(with: file.text)
        isApplyingExternalChange = false
    }

    // MARK: View state

    /// Remembers caret and scroll position before this editor is released.
    func captureViewState() {
        file.viewState = EditorViewState(
            selection: textView.selectedRange(),
            scrollY: contentView.bounds.origin.y
        )
    }

    private func restoreViewState() {
        guard let state = file.viewState else { return }
        let length = (textView.string as NSString).length
        let location = min(state.selection.location, length)
        textView.setSelectedRange(NSRange(location: location, length: min(state.selection.length, length - location)))
        contentView.scroll(to: NSPoint(x: 0, y: state.scrollY))
        reflectScrolledClipView(contentView)
    }

    // MARK: Delegate

    func textViewDidChangeSelection(_ notification: Notification) {
        onCaretMove(file, textView.caretLine)
    }

    func textDidChange(_ notification: Notification) {
        guard !isApplyingExternalChange else { return }
        file.text = textView.string
        onTextChange(file)
    }
}
