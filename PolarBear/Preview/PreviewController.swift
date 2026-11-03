//
//  PreviewController.swift
//  PolarBear
//

import Observation
import PDFKit

/// The state of one preview (zoom, page, text mode) and the actions on its `PDFView`.
@Observable
final class PreviewController {
    var zoom: PDFZoom = .fit {
        didSet {
            guard zoom != oldValue else { return }
            if !isAdoptingViewZoom { applyZoom() }
            onZoomChange?(zoom)
        }
    }
    private(set) var pageIndex = 0
    private(set) var pageCount = 0
    /// Shows the PDF's text instead of its pages (for screen readers and copying).
    var isTextMode = false

    @ObservationIgnored weak var pdfView: PDFView?
    @ObservationIgnored var onZoomChange: ((PDFZoom) -> Void)?
    @ObservationIgnored private var highlightTask: Task<Void, Never>?
    /// Greater than zero while the code (not the reader) is changing the view's scale.
    @ObservationIgnored private var ownScaleChanges = 0
    /// `zoom` is being set from the view's own scale (a pinch), so it must not be applied back.
    @ObservationIgnored private var isAdoptingViewZoom = false

    init(zoom: PDFZoom = .fit) {
        self.zoom = zoom
    }

    // MARK: Connection to the view

    func attach(_ view: PDFView) {
        pdfView = view
        applyZoom()
        refreshPagination()
    }

    func refreshPagination() {
        guard let view = pdfView, let document = view.document else {
            pageIndex = 0
            pageCount = 0
            return
        }
        pageCount = document.pageCount
        pageIndex = view.currentPage.map { document.index(for: $0) } ?? 0
    }

    /// Shows the PDF at `zoom` and keeps the top-left of what the reader sees in place.
    func applyZoom() {
        guard let view = pdfView else { return }
        let place = view.document == nil ? nil : view.currentDestination

        withoutFollowingScale {
            view.minScaleFactor = Self.minimumScale
            view.maxScaleFactor = Self.maximumScale
            switch zoom {
            case .fit:
                view.autoScales = true
            case .percent(let value):
                view.autoScales = false
                view.scaleFactor = min(max(Double(value) / 100, Self.minimumScale), Self.maximumScale)
            }
            view.layoutDocumentView()
            if let place { view.go(to: place) }
        }
    }

    /// Runs `change`, which alters the view's scale on purpose, without treating it as the reader zooming.
    func withoutFollowingScale(_ change: () -> Void) {
        ownScaleChanges += 1
        defer { ownScaleChanges -= 1 }
        change()
    }

    // MARK: Zoom made in the view (pinch, double-tap)

    /// PDFKit changed the scale. If that was not us and not PDFKit fitting the page to the panel,
    /// the reader pinched: take over, so PDFKit does not snap the page back to "fit" underneath
    /// them, and make the menu label and the saved zoom follow.
    func viewScaleDidChange() {
        guard ownScaleChanges == 0, let view = pdfView, view.document != nil else { return }
        let scale = view.scaleFactor
        let fit = view.scaleFactorForSizeToFit
        let isAtFit = fit > 0 && abs(scale - fit) / fit < Self.fitTolerance

        if view.autoScales {
            // PDFKit refitting after a resize lands exactly on the fit scale; anything else is a pinch.
            guard !isAtFit, fit > 0 else { return }
            withoutFollowingScale { view.autoScales = false }
        } else if isAtFit {
            // Pinched back to the fitted size: go back to "fit" so it follows the panel again.
            withoutFollowingScale { view.autoScales = true }
        }
        adopt(isAtFit ? .fit : .percent(Int((scale * 100).rounded())))
    }

    /// Makes `zoom` (the menu label, the saved value, "Zoom to Fit") match what the view shows.
    private func adopt(_ shown: PDFZoom) {
        guard shown != zoom else { return }
        isAdoptingViewZoom = true
        zoom = shown
        isAdoptingViewZoom = false
    }

    // MARK: Zooming

    private static let minimumScale = 0.25
    private static let fitTolerance = 0.01
    private static let maximumScale = 5.0

    private var currentPercent: Int {
        Int(((pdfView?.scaleFactor ?? 1) * 100).rounded())
    }

    func zoomIn() {
        zoom = PDFZoom.larger(than: currentPercent)
    }

    func zoomOut() {
        zoom = PDFZoom.smaller(than: currentPercent)
    }

    func zoomToFit() {
        zoom = .fit
    }

    // MARK: Pages

    func goToPage(_ index: Int) {
        guard let document = pdfView?.document, (0..<document.pageCount).contains(index),
              let page = document.page(at: index) else { return }
        pdfView?.go(to: PDFDestination(page: page, at: NSPoint(x: 0, y: page.bounds(for: .cropBox).maxY)))
    }

    func nextPage() {
        goToPage(pageIndex + 1)
    }

    func previousPage() {
        goToPage(pageIndex - 1)
    }

    // MARK: Showing a location

    /// Scrolls to `rect` (PDF points, origin bottom-left) on page `index` and outlines it briefly.
    func reveal(_ rect: CGRect, onPage index: Int) {
        guard let view = pdfView, let page = view.document?.page(at: index) else { return }
        view.go(to: rect.insetBy(dx: -40, dy: -80), on: page)

        let outline = PDFAnnotation(bounds: rect.insetBy(dx: -2, dy: -2), forType: .square, withProperties: nil)
        outline.color = .systemYellow
        outline.border = PDFBorder()
        outline.border?.lineWidth = 1.5
        page.addAnnotation(outline)

        highlightTask?.cancel()
        highlightTask = Task { [weak page] in
            do {
                try await Task.sleep(for: .milliseconds(1600))
            } catch {
                page?.removeAnnotation(outline)
                return
            }
            page?.removeAnnotation(outline)
        }
    }
}
