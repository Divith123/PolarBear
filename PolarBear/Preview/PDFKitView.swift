//
//  PDFKitView.swift
//  PolarBear
//

import PDFKit
import SwiftUI

/// The real PDF: PDFKit's renderer on a black background, with selectable text. When a new
/// build is published the document is swapped in place and the reader keeps their place.
struct PDFKitView: NSViewRepresentable {
    let url: URL
    /// Changes when `url` holds a new PDF.
    let generation: Int
    let preview: PreviewController
    let onCommandClick: (_ pageIndex: Int, _ point: CGPoint) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> SyncPDFView {
        let view = SyncPDFView()
        view.backgroundColor = AppTheme.NS.pdfBackground
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.displaysPageBreaks = true
        view.pageBreakMargins = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        view.autoScales = true
        view.interpolationQuality = .high

        for case let scroll as NSScrollView in view.subviews {
            scroll.scrollerStyle = .overlay
            scroll.autohidesScrollers = true
            scroll.scrollerKnobStyle = .default
            scroll.drawsBackground = false
        }

        preview.attach(view)
        context.coordinator.observe(view, preview: preview)
        return view
    }

    /// The PDF fills whatever space the panel offers; its own size never drives the layout.
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: SyncPDFView, context: Context) -> CGSize? {
        CGSize(
            width: proposal.width ?? AppTheme.Metrics.previewIdeal,
            height: proposal.height ?? AppTheme.Metrics.previewIdeal
        )
    }

    func updateNSView(_ view: SyncPDFView, context: Context) {
        view.onCommandClick = onCommandClick
        guard context.coordinator.loadedGeneration != generation else { return }
        context.coordinator.loadedGeneration = generation

        guard let document = PDFDocument(url: url) else { return }
        let place = view.currentDestination
        let pageIndex = view.currentPage.flatMap { view.document?.index(for: $0) }

        preview.withoutFollowingScale {
            view.document = document
        }
        preview.applyZoom()

        // Put the reader back where they were instead of at the top of the new PDF.
        if let place, let pageIndex, let page = document.page(at: min(pageIndex, document.pageCount - 1)) {
            view.go(to: PDFDestination(page: page, at: place.point))
        }
        preview.refreshPagination()
    }

    @MainActor
    final class Coordinator {
        var loadedGeneration = -1
        private var pageObserver: Task<Void, Never>?
        private var scaleObservers: [NSObjectProtocol] = []
        private var magnificationObserver: NSKeyValueObservation?

        func observe(_ view: PDFView, preview: PreviewController) {
            pageObserver = Task { [weak view, weak preview] in
                for await _ in NotificationCenter.default.notifications(named: .PDFViewPageChanged, object: view) {
                    guard view != nil else { return }
                    preview?.refreshPagination()
                }
            }
            // A pinch magnifies PDFView's inner scroll view directly: PDFKit neither posts a scale
            // notification nor leaves "fit" mode, so the next layout would snap the page back. Both
            // the notification and the magnification are watched, synchronously, to take over.
            scaleObservers = [
                NotificationCenter.default.addObserver(forName: .PDFViewScaleChanged, object: view, queue: nil) { [weak preview] _ in
                    MainActor.assumeIsolated { preview?.viewScaleDidChange() }
                },
            ]
            if let scroll = view.subviews.lazy.compactMap({ $0 as? NSScrollView }).first {
                magnificationObserver = scroll.observe(\.magnification, options: [.new]) { [weak preview] _, _ in
                    MainActor.assumeIsolated { preview?.viewScaleDidChange() }
                }
            }
        }

        isolated deinit {
            pageObserver?.cancel()
            magnificationObserver?.invalidate()
            scaleObservers.forEach { NotificationCenter.default.removeObserver($0) }
        }
    }
}
