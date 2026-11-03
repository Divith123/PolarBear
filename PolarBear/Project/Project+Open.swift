//
//  Project+Open.swift
//  PolarBear
//

import Foundation

extension Project {
    /// Opens the folder at `url` as a project: reads its files, starts watching it and loads
    /// its history and last PDF.
    static func open(at url: URL, scope: SecurityScope?, toolchain: ToolchainModel) async -> Project {
        let root = url.resolvingSymlinksInPath()
        let settings = await ProjectSettings.load(from: root)
        let scan = await ProjectScanner.scan(root: root, known: [:])
        let project = Project(root: root, scope: scope, settings: settings, scan: scan, toolchain: toolchain)
        project.startWatching()
        await project.history.load()
        await project.agent.load(root: root)
        project.adoptPublishedPDF()
        return project
    }

    /// Shows the PDF an earlier session left behind, so the preview is not empty while the
    /// first build runs.
    private func adoptPublishedPDF() {
        guard let rootFile = resolvedRootFile else { return }
        let name = rootFile.split(separator: "/").last.map { String($0.dropLast(4)) } ?? rootFile
        let directory = ProjectPaths.publishedDirectory(in: root)
        let pdf = directory.appending(path: name + ".pdf")
        guard FileManager.default.fileExists(atPath: pdf.path(percentEncoded: false)) else { return }
        let synctex = directory.appending(path: name + ".synctex.gz")
        build.adoptPublished(
            pdf: pdf,
            synctex: FileManager.default.fileExists(atPath: synctex.path(percentEncoded: false)) ? synctex : nil
        )
    }
}
