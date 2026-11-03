//
//  WorkspaceModel+Markdown.swift
//  PolarBear
//

import SwiftUI

/// The Markdown project's download and copy commands, and the TeX ⇄ Markdown switch.
extension WorkspaceModel {
    /// `nil` unless the project is a Markdown project.
    var markdownActions: MarkdownActions? {
        guard project.settings.mode == .markdown else { return nil }
        return MarkdownActions(
            downloadMarkdown: { [self] in downloadMarkdown() },
            downloadPDF: { [self] in exportPDF() },
            copy: { [self] format in copyMarkdown(as: format) }
        )
    }

    /// The Markdown file the preview shows.
    private var markdownFile: ProjectFile? {
        project.resolvedRootFile.flatMap { project.file(atPath: $0) }
    }

    func switchMode(_ mode: DocumentMode) {
        Task {
            if let target = await project.setMode(mode) { open(target) }
            refreshOutline()
        }
    }

    func downloadMarkdown() {
        guard let file = markdownFile else { return }
        guard let destination = FilePanels.chooseSaveLocation(
            suggestedName: ProjectPath.stem(of: file.path) + ".md",
            message: String(localized: "Choose where to save the Markdown file.")
        ) else { return }
        do {
            guard let data = file.serializedText.data(using: file.encoding) else { throw CocoaError(.fileWriteInapplicableStringEncoding) }
            try data.write(to: destination, options: .atomic)
            NSWorkspace.shared.activateFileViewerSelecting([destination])
        } catch {
            report(error)
        }
    }

    func copyMarkdown(as format: MarkdownCopyFormat) {
        guard let file = markdownFile else { return }
        MarkdownClipboard.copy(
            file.text,
            as: format,
            baseDirectory: project.absoluteURL(for: file.path).deletingLastPathComponent(),
            title: ProjectPath.stem(of: file.path),
            imageCache: ProjectPaths.imageCacheDirectory(in: project.root),
            loadsRemoteImages: project.settings.loadsRemoteImages
        )
    }
}
