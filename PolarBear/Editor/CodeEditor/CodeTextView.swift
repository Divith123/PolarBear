//
//  CodeTextView.swift
//  PolarBear
//

import SwiftUI

/// A TextKit 1 text view with hanging-indent soft wrapping, LaTeX highlighting, auto-indent
/// and a line-number gutter (drawn by `DecorationView`). Highlighting lives in
/// `CodeTextView+Highlighting`.
final class CodeTextView: NSTextView, NSTextStorageDelegate {
    /// `NSTextStorage` is only weakly referenced by its layout manager, so keep it alive here.
    private let retainedStorage: NSTextStorage
    private let decorations = DecorationView()
    private var paragraphStyles: [Int: NSParagraphStyle] = [:]

    var language = SourceLanguage.tex
    var lineStarts = [0]
    /// The state after each line (inside `$…$` math in TeX, inside a code fence in Markdown), so a
    /// change only re-colours the lines it can affect.
    var endStates: [Bool] = []
    /// The range the last text change touched, in the new text.
    var pendingEdit: NSRange?
    var needsFullHighlight = true

    /// Problems to mark in the gutter, by 1-based line.
    var markers: [Int: Diagnostic.Severity] = [:] {
        didSet { decorations.needsDisplay = true }
    }
    /// Called after a ⌘-click with the line the caret is on.
    var onCommandClick: ((Int) -> Void)?

    init() {
        let storage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)
        let container = NSTextContainer(size: NSSize(width: 400, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = false
        container.lineFragmentPadding = 0
        layoutManager.addTextContainer(container)
        retainedStorage = storage

        super.init(frame: NSRect(x: 0, y: 0, width: 400, height: 100), textContainer: container)
        storage.delegate = self
        configureEditing()
        configureLayout()

        decorations.owner = self
        decorations.frame = bounds
        decorations.autoresizingMask = [.width, .height]
        addSubview(decorations)
    }

    required init?(coder: NSCoder) {
        fatalError("CodeTextView is created in code only")
    }

    private func configureEditing() {
        isRichText = false
        importsGraphics = false
        allowsUndo = true
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isAutomaticLinkDetectionEnabled = false
        isAutomaticDataDetectionEnabled = false
        isContinuousSpellCheckingEnabled = false
        isGrammarCheckingEnabled = false
        smartInsertDeleteEnabled = false
        usesFindBar = true
        isIncrementalSearchingEnabled = true

        drawsBackground = false
        insertionPointColor = SyntaxPalette.caret
        selectedTextAttributes = [.backgroundColor: SyntaxPalette.selection]
    }

    private func configureLayout() {
        isVerticallyResizable = true
        isHorizontallyResizable = false
        autoresizingMask = [.width]
        maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textContainerInset = NSSize(width: CodeMetrics.gutterWidth, height: CodeMetrics.topInset)

        font = CodeMetrics.font
        typingAttributes = baseAttributes(indent: 0)
    }

    // MARK: Attributes shared with the highlighter

    /// Paragraph style with a hanging indent of `indent` columns, shared between lines.
    func paragraphStyle(indent: Int) -> NSParagraphStyle {
        if let cached = paragraphStyles[indent] { return cached }
        let style = NSMutableParagraphStyle()
        style.lineSpacing = CodeMetrics.lineSpacing
        style.lineBreakMode = .byWordWrapping
        style.headIndent = CGFloat(indent) * CodeMetrics.characterWidth
        style.firstLineHeadIndent = 0
        paragraphStyles[indent] = style
        return style
    }

    func baseAttributes(indent: Int) -> [NSAttributedString.Key: Any] {
        [
            .font: CodeMetrics.font,
            .foregroundColor: SyntaxPalette.text,
            .paragraphStyle: paragraphStyle(indent: indent),
        ]
    }

    // MARK: Loading

    /// Replaces everything (a file was opened, or it changed on disk) and starts at the top.
    func load(text: String, language: SourceLanguage) {
        self.language = language
        string = text
        setSelectedRange(NSRange(location: 0, length: 0))
        rebuildLineStarts()
        highlightEverything()
        undoManager?.removeAllActions()
    }

    /// Swaps in new text (changed by another program, an agent or a restore) as one undoable edit,
    /// keeping the caret and scroll position where they were.
    func replaceContents(with text: String) {
        guard text != string else { return }
        let selection = selectedRange()
        let scroll = enclosingScrollView?.contentView.bounds.origin ?? .zero
        let whole = NSRange(location: 0, length: (string as NSString).length)

        if shouldChangeText(in: whole, replacementString: text) {
            textStorage?.replaceCharacters(in: whole, with: text)
            didChangeText()
        }
        let length = (string as NSString).length
        let location = min(selection.location, length)
        setSelectedRange(NSRange(location: location, length: min(selection.length, length - location)))
        if let clip = enclosingScrollView?.contentView {
            clip.scroll(to: scroll)
            enclosingScrollView?.reflectScrolledClipView(clip)
        }
    }

    func setLanguage(_ newValue: SourceLanguage) {
        guard newValue != language else { return }
        language = newValue
        highlightEverything()
    }

    // MARK: Layout

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateContainerWidth()
    }

    private func updateContainerWidth() {
        guard let container = textContainer else { return }
        let width = max(bounds.width - CodeMetrics.gutterWidth - CodeMetrics.trailingPadding, 60)
        if abs(container.size.width - width) > 0.5 {
            container.size = NSSize(width: width, height: .greatestFiniteMagnitude)
        }
    }

    /// Puts the caret on `line` (1-based) and scrolls it near the top.
    func reveal(line: Int) {
        let ns = string as NSString
        var index = 0
        var current = 1
        while current < line, index < ns.length {
            index = NSMaxRange(ns.lineRange(for: NSRange(location: index, length: 0)))
            current += 1
        }
        setSelectedRange(NSRange(location: index, length: 0))

        guard ns.length > 0, let layoutManager, let textContainer else { return }
        layoutManager.ensureLayout(for: textContainer)
        let glyph = layoutManager.glyphIndexForCharacter(at: min(index, ns.length - 1))
        let rect = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
        let targetY = max(rect.minY + textContainerOrigin.y - 60, 0)
        if let clip = enclosingScrollView?.contentView {
            clip.scroll(to: NSPoint(x: 0, y: targetY))
            enclosingScrollView?.reflectScrolledClipView(clip)
        }
    }

    /// The 1-based line the caret is on.
    var caretLine: Int {
        lineNumber(at: min(selectedRange().location, (string as NSString).length))
    }

    // MARK: Editing behaviour

    override func insertTab(_ sender: Any?) {
        insertText("  ", replacementRange: selectedRange())
    }

    /// Keeps the indentation of the line the caret was on.
    override func insertNewline(_ sender: Any?) {
        let ns = string as NSString
        let caret = min(selectedRange().location, ns.length)
        let lineRange = ns.lineRange(for: NSRange(location: caret, length: 0))
        let beforeCaret = ns.substring(with: NSRange(location: lineRange.location, length: caret - lineRange.location))
        let indent = String(beforeCaret.prefix(while: { $0 == " " || $0 == "\t" }))

        super.insertNewline(sender)
        if !indent.isEmpty {
            insertText(indent, replacementRange: selectedRange())
        }
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        if event.modifierFlags.contains(.command) {
            onCommandClick?(caretLine)
        }
    }

    override func didChangeText() {
        rebuildLineStarts()
        applyHighlightingAfterEdit()
        decorations.needsDisplay = true
        super.didChangeText()
    }

    override func unmarkText() {
        super.unmarkText()
        highlightEverything()
    }

    override func setSelectedRanges(_ ranges: [NSValue], affinity: NSSelectionAffinity, stillSelecting stillSelectingFlag: Bool) {
        super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: stillSelectingFlag)
        decorations.needsDisplay = true
    }

    func textStorage(
        _ textStorage: NSTextStorage,
        didProcessEditing editedMask: NSTextStorageEditActions,
        range editedRange: NSRange,
        changeInLength delta: Int
    ) {
        guard editedMask.contains(.editedCharacters) else { return }
        if pendingEdit == nil {
            pendingEdit = editedRange
        } else {
            needsFullHighlight = true // Several edits before we looked: ranges no longer line up.
        }
    }

    // MARK: Decorations

    /// Frame of the paragraph holding the caret, in this view's coordinates; `nil` while text is selected.
    func activeLineRect() -> NSRect? {
        guard let layoutManager, let textContainer, selectedRange().length == 0 else { return nil }
        let ns = string as NSString
        let caret = min(selectedRange().location, ns.length)
        var rect: NSRect

        if caret == ns.length, ns.length == 0 || ns.character(at: ns.length - 1) == 10 {
            rect = layoutManager.extraLineFragmentRect
            if rect.isEmpty { return nil }
        } else {
            let paragraph = ns.paragraphRange(for: NSRange(location: caret, length: 0))
            let glyphs = layoutManager.glyphRange(forCharacterRange: paragraph, actualCharacterRange: nil)
            rect = layoutManager.boundingRect(forGlyphRange: glyphs, in: textContainer)
        }

        // The extra line spacing sits below each row; centre the box on the text.
        let x = CodeMetrics.gutterWidth
        let y = rect.minY + textContainerOrigin.y - CodeMetrics.lineSpacing / 2
        return NSRect(x: x, y: y, width: max(bounds.width - x - 3, 0), height: rect.height)
    }

    func rebuildLineStarts() {
        let ns = string as NSString
        var starts = [0]
        for index in 0..<ns.length where ns.character(at: index) == 10 {
            starts.append(index + 1)
        }
        lineStarts = starts
    }

    /// 1-based logical line number containing the UTF-16 offset `index`.
    func lineNumber(at index: Int) -> Int {
        var low = 0
        var high = lineStarts.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if lineStarts[mid] <= index { low = mid } else { high = mid - 1 }
        }
        return low + 1
    }

    /// Draws a number next to the first row of every visible logical line.
    func drawLineNumbers() {
        guard let layoutManager, let textContainer else { return }
        let ns = string as NSString
        let origin = textContainerOrigin
        let visible = visibleRect.isEmpty ? bounds : visibleRect
        let caretLine: Int? = selectedRange().length == 0 ? lineNumber(at: min(selectedRange().location, ns.length)) : nil

        func draw(_ number: Int, baseline: CGFloat) {
            let marker = markers[number]
            let colour: NSColor = switch marker {
            case .error: SyntaxPalette.errorMarker
            case .warning: SyntaxPalette.warningMarker
            default: number == caretLine ? SyntaxPalette.activeLineNumber : SyntaxPalette.lineNumber
            }
            let attributes: [NSAttributedString.Key: Any] = [.font: CodeMetrics.font, .foregroundColor: colour]
            let label = "\(number)" as NSString
            let width = label.size(withAttributes: attributes).width
            label.draw(
                at: NSPoint(x: CodeMetrics.numberTrailingEdge - width, y: baseline - CodeMetrics.font.ascender),
                withAttributes: attributes
            )
            if let marker, marker != .info {
                let dot = NSRect(x: 9, y: baseline - CodeMetrics.font.ascender / 2 - 3, width: 6, height: 6)
                colour.setFill()
                NSBezierPath(ovalIn: dot).fill()
            }
        }

        if ns.length > 0 {
            let containerRect = NSRect(x: 0, y: visible.minY - origin.y, width: textContainer.size.width, height: visible.height)
            let glyphRange = layoutManager.glyphRange(forBoundingRect: containerRect, in: textContainer)
            let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            var index = ns.paragraphRange(for: NSRange(location: min(charRange.location, ns.length - 1), length: 0)).location

            while index < ns.length {
                let glyph = layoutManager.glyphIndexForCharacter(at: index)
                let fragment = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
                if fragment.minY + origin.y > visible.maxY { break }
                let baseline = fragment.minY + origin.y + CodeMetrics.font.ascender
                draw(lineNumber(at: index), baseline: baseline)
                index = NSMaxRange(ns.paragraphRange(for: NSRange(location: index, length: 0)))
            }
        }

        // Trailing empty line (the document is empty or ends with a newline).
        if ns.length == 0 || ns.character(at: ns.length - 1) == 10 {
            let fragment = layoutManager.extraLineFragmentRect
            if !fragment.isEmpty {
                draw(lineStarts.count, baseline: fragment.minY + origin.y + CodeMetrics.font.ascender)
            }
        }
    }
}
