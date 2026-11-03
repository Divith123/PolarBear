//
//  DecorationView.swift
//  PolarBear
//

import SwiftUI

/// Transparent, click-through view laid over the text view. It draws the line-number gutter
/// and the current-line outline in its own clean graphics context.
final class DecorationView: NSView {
    weak var owner: CodeTextView?

    /// Current-line outline; a layer so it can use the smooth `.continuous` corner curve.
    private let outline = CALayer()

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        outline.cornerRadius = 4
        outline.cornerCurve = .continuous
        outline.borderWidth = 1
        outline.borderColor = SyntaxPalette.activeLineBorder.cgColor
        outline.isHidden = true
        outline.actions = ["position": NSNull(), "bounds": NSNull(), "frame": NSNull(), "hidden": NSNull()]
        layer?.addSublayer(outline)
    }

    required init?(coder: NSCoder) {
        fatalError("DecorationView is created in code only")
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        effectiveAppearance.performAsCurrentDrawingAppearance {
            outline.borderColor = SyntaxPalette.activeLineBorder.cgColor
        }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        owner?.drawLineNumbers()
        if let rect = owner?.activeLineRect() {
            outline.frame = rect.insetBy(dx: 0.5, dy: 0.5)
            outline.isHidden = false
        } else {
            outline.isHidden = true
        }
    }
}
