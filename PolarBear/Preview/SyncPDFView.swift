//
//  SyncPDFView.swift
//  PolarBear
//

import PDFKit
import SwiftUI

/// A `PDFView` that reports ⌘-clicks (as a page and a point on it) instead of selecting text,
/// so a click in the PDF can jump to the source line.
final class SyncPDFView: PDFView {
    var onCommandClick: ((_ pageIndex: Int, _ point: CGPoint) -> Void)?
    /// PDFKit reports the size of the whole document (times the zoom) as its natural size. SwiftUI
    /// would then grow the panel and the window with every zoom step, so report none.
    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }

    override func mouseDown(with event: NSEvent) {
        guard event.modifierFlags.contains(.command), let document else {
            super.mouseDown(with: event)
            return
        }
        let location = convert(event.locationInWindow, from: nil)
        guard let page = page(for: location, nearest: true) else { return }
        onCommandClick?(document.index(for: page), convert(location, to: page))
    }
}
