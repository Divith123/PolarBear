//
//  MarkdownClipboard.swift
//  PolarBear
//

import SwiftUI

/// Puts a Markdown document on the pasteboard as rich text, HTML source or plain text.
@MainActor
enum MarkdownClipboard {
    /// - Parameters:
    ///   - source: the Markdown text.
    ///   - baseDirectory: the folder of the Markdown file, for its images.
    static func copy(
        _ source: String,
        as format: MarkdownCopyFormat,
        baseDirectory: URL,
        title: String,
        imageCache: URL,
        loadsRemoteImages: Bool
    ) {
        let document = MarkdownDocument(source: source)
        let pasteboard = NSPasteboard.general

        switch format {
        case .plainText:
            pasteboard.clearContents()
            pasteboard.setString(MarkdownPlainTextWriter.write(document), forType: .string)

        case .html:
            var writer = MarkdownHTMLWriter(baseDirectory: baseDirectory, imageMode: .asWritten)
            writer.keepsRemoteImagesAsWritten = true
            pasteboard.clearContents()
            pasteboard.setString(writer.write(document), forType: .string)

        case .richText:
            // Web images are downloaded first (the importer would otherwise fetch them on the main thread).
            let sources = loadsRemoteImages ? document.remoteImageSources : []
            Task {
                var images = MarkdownImageStore.Result()
                if !sources.isEmpty { images = await MarkdownImageStore.fetch(sources, into: imageCache) }
                copyRichText(document, baseDirectory: baseDirectory, title: title, images: images)
            }
        }
    }

    private static func copyRichText(_ document: MarkdownDocument, baseDirectory: URL, title: String, images: MarkdownImageStore.Result) {
        var writer = MarkdownHTMLWriter(baseDirectory: baseDirectory, imageMode: .absoluteFiles)
        writer.mathMode = .source
        writer.rendersDiagrams = false
        writer.remoteImages = images.files
        writer.remoteFailures = images.failures
        let page = MarkdownPage.html(body: writer.write(document), title: title, style: .clipboard)
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue,
            .baseURL: baseDirectory,
        ]
        guard let attributed = try? NSAttributedString(data: Data(page.utf8), options: options, documentAttributes: nil) else {
            return
        }
        let whole = NSRange(location: 0, length: attributed.length)
        let item = NSPasteboardItem()
        if let rtfd = attributed.rtfd(from: whole) { item.setData(rtfd, forType: .rtfd) }
        if let rtf = attributed.rtf(from: whole) { item.setData(rtf, forType: .rtf) }
        item.setData(Data(page.utf8), forType: .html)
        item.setString(attributed.string, forType: .string)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([item])
    }
}
