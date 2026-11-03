//
//  SyncTeXService.swift
//  PolarBear
//

import CoreGraphics
import Foundation
import PDFKit
import os

/// Answers "where in the PDF is this line?" and "which line made this spot?" for one project,
/// from the SyncTeX data of the latest published PDF. The data is parsed once per build.
final class SyncTeXService {
    struct SourceHit {
        var file: String
        var line: Int
    }

    var root: URL
    /// The published `.synctex.gz` and the build it belongs to.
    var source: (() -> (url: URL?, generation: Int))?

    private var cached: (generation: Int, index: SyncTeXIndex)?

    init(root: URL) {
        self.root = root
    }

    private func index() async -> SyncTeXIndex? {
        guard let (url, generation) = source?(), let url else { return nil }
        if let cached, cached.generation == generation { return cached.index }
        guard let parsed = await Self.load(url) else { return nil }
        cached = (generation, parsed)
        return parsed
    }

    @concurrent
    private static func load(_ url: URL) async -> SyncTeXIndex? {
        do {
            let text = String(decoding: try GzipDecoder.decode(Data(contentsOf: url)), as: UTF8.self)
            return SyncTeXIndex.parse(text)
        } catch {
            Log.sync.error("Could not read SyncTeX data: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: Source → PDF

    /// Scrolls `preview` to the part of the page that `line` of `path` produced.
    func showPDF(for path: String, line: Int, in preview: PreviewController) async {
        guard let index = await index() else { return }
        let absolute = root.appending(path: path).standardizedFileURL.path(percentEncoded: false)
        guard let tag = index.tag(forPath: absolute) ?? index.tag(forPath: path),
              let location = index.pdfLocation(tag: tag, line: line),
              let page = preview.pdfView?.document?.page(at: location.page) else { return }

        // SyncTeX measures from the top of the page, PDFKit from the bottom.
        let bounds = page.bounds(for: .mediaBox)
        let union = location.union
        let rect = CGRect(x: bounds.minX + union.minX, y: bounds.minY + bounds.height - union.maxY, width: union.width, height: union.height)
        preview.reveal(rect, onPage: location.page)
    }

    // MARK: PDF → source

    /// The project file and line behind a click at `point` (PDFKit page coordinates) on page `pageIndex`.
    func sourceLocation(pageIndex: Int, point: CGPoint, in preview: PreviewController) async -> SourceHit? {
        guard let index = await index(),
              let page = preview.pdfView?.document?.page(at: pageIndex) else { return nil }
        let rootPath = root.standardizedFileURL.path(percentEncoded: false)

        // PDFKit measures from the bottom of the page, SyncTeX from the top.
        let bounds = page.bounds(for: .mediaBox)
        let fromTop = bounds.height - (point.y - bounds.minY)
        guard let hit = index.sourceLocation(page: pageIndex, x: Double(point.x - bounds.minX), y: Double(fromTop)) else {
            return nil
        }
        var path = hit.file
        if path.hasPrefix(rootPath + "/") { path = String(path.dropFirst(rootPath.count + 1)) }
        else if !path.hasPrefix("/") { path = RootResolver.normalise(path) }
        return SourceHit(file: path, line: hit.line)
    }
}
