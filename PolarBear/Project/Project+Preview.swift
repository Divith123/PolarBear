//
//  Project+Preview.swift
//  PolarBear
//

import Foundation

extension Project {
    /// A project over a throw-away folder with one sample file, for previews. It never touches
    /// the disk.
    static var preview: Project {
        let sample = FileIO.DecodedText(text: TemplateCatalog.articleSource, encoding: .utf8, usesCRLF: false)
        let scan = ProjectScanner.Scan(
            files: [ProjectScanner.ScannedFile(path: "main.tex", stamp: .none, content: .loaded(sample))],
            assets: [],
            folders: []
        )
        return Project(
            root: FileManager.default.temporaryDirectory.appending(path: "PolarBear Preview", directoryHint: .isDirectory),
            scope: nil,
            settings: ProjectSettings(),
            scan: scan,
            toolchain: ToolchainModel()
        )
    }
}
