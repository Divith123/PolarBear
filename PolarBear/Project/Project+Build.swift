//
//  Project+Build.swift
//  PolarBear
//

import Foundation
import os

extension Project {
    /// The file that is compiled: a `.tex` file, or in a Markdown project the `.md` file being edited.
    var resolvedRootFile: String? {
        if settings.mode == .markdown {
            return RootResolver.resolveMarkdown(paths: files.map(\.path), explicit: settings.rootFile, active: settings.activeTab)
        }
        let sources = files.filter { $0.kind == .tex }.map { RootResolver.Source(path: $0.path, text: $0.text) }
        let active = settings.activeTab.flatMap { path in sources.first { $0.path == path } }
        return RootResolver.resolve(sources: sources, explicit: settings.rootFile, active: active)
    }

    /// The engine the next build will use.
    var effectiveEngine: TeXEngine? {
        let magic = resolvedRootFile.flatMap { file(atPath: $0) }.map { MagicComments(text: $0.text).program } ?? nil
        return toolchain.toolchain.resolve(explicit: settings.engine, magic: magic)
    }

    func makeBuildRequest() -> Result<BuildRequest, ToolProblem> {
        guard let rootFile = resolvedRootFile else {
            return .failure(settings.mode == .markdown ? .noMarkdownFile : .noRootFile)
        }
        // Markdown is rendered by PolarBear itself; no TeX engine is needed.
        let engine: TeXEngine
        if settings.mode == .markdown {
            engine = .tectonic
        } else if let found = effectiveEngine {
            engine = found
        } else {
            return .failure(.noEngine)
        }
        return .success(
            BuildRequest(
                root: root,
                rootFile: rootFile,
                mode: settings.mode,
                engine: engine,
                toolchain: toolchain.toolchain,
                shellEscape: settings.shellEscape,
                loadsRemoteImages: settings.loadsRemoteImages,
                knownFiles: Set(files.map(\.path)),
                folders: folders
            )
        )
    }

    /// Compiles now (⌘R).
    func compile() {
        build.requestBuild()
    }

    /// A finished build is the moment to refresh anything derived from the PDF.
    func buildDidFinish(_ outcome: BuildOutcome) {
        Log.build.info("Build finished: \(outcome.errorCount) errors, \(outcome.warningCount) warnings in \(outcome.duration, format: .fixed(precision: 2))s")
    }

    /// Copies the published PDF to `destination`.
    func exportPDF(to destination: URL) throws {
        guard let pdf = build.publishedPDF else { throw CocoaError(.fileNoSuchFile) }
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destination.path(percentEncoded: false)) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: pdf, to: destination)
    }
}
