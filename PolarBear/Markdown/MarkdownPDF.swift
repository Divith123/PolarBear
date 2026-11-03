//
//  MarkdownPDF.swift
//  PolarBear
//

import SwiftUI
import WebKit

/// Turns a rendered HTML page into a paginated PDF with WebKit's own print engine: real page
/// breaks, selectable text and working links. Nothing is shown on screen, no script runs and
/// no network request is made.
@MainActor
enum MarkdownPDF {
    struct RenderError: LocalizedError {
        var errorDescription: String?
    }

    private static let margin = 54.0
    private static let loadTimeout = Duration.seconds(20)

    /// Writes `page` (an HTML file) as a PDF at `destination`. `readAccess` is the folder whose
    /// images the page may use.
    static func render(page: URL, readAccess: URL, to destination: URL) async throws {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false

        let paper = NSPrintInfo.shared.paperSize
        let contentSize = NSSize(width: paper.width - margin * 2, height: paper.height - margin * 2)
        let webView = WKWebView(frame: NSRect(origin: .zero, size: contentSize), configuration: configuration)
        let window = NSWindow(contentRect: webView.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = webView
        window.isReleasedWhenClosed = false
        defer { window.close() }

        let session = MarkdownPDFSession()
        let timeout = Task {
            try await Task.sleep(for: loadTimeout)
            session.abandonLoad(with: RenderError(errorDescription: String(localized: "The page took too long to load.")))
        }
        defer { timeout.cancel() }
        try await session.load(page, readAccess: readAccess, in: webView)
        try Task.checkCancellation()

        let temporary = destination.deletingLastPathComponent().appending(path: ".render-\(UUID().uuidString).pdf")
        let info = NSPrintInfo()
        info.paperSize = paper
        info.topMargin = margin
        info.bottomMargin = margin
        info.leftMargin = margin
        info.rightMargin = margin
        info.isHorizontallyCentered = false
        info.isVerticallyCentered = false
        info.jobDisposition = .save
        info.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = temporary

        let operation = webView.printOperation(with: info)
        operation.showsPrintPanel = false
        operation.showsProgressPanel = false
        operation.view?.frame = NSRect(origin: .zero, size: contentSize)

        let succeeded = await session.run(operation, in: window)
        guard succeeded, FileManager.default.fileExists(atPath: temporary.path(percentEncoded: false)) else {
            try? FileManager.default.removeItem(at: temporary)
            throw RenderError(errorDescription: String(localized: "The PDF could not be created."))
        }

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destination.path(percentEncoded: false)) {
            _ = try fileManager.replaceItemAt(destination, withItemAt: temporary)
        } else {
            try fileManager.moveItem(at: temporary, to: destination)
        }
    }
}
