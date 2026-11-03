//
//  Project+Mode.swift
//  PolarBear
//

import Foundation

extension Project {
    /// Switches the whole project between TeX and Markdown and starts a build. Returns the file
    /// to show: the Markdown document (a starter `main.md` is created if the project has none) or
    /// the TeX main file.
    func setMode(_ newMode: DocumentMode) async -> ProjectFile? {
        guard newMode != settings.mode else { return nil }
        settings.mode = newMode

        var target = resolvedRootFile.flatMap { file(atPath: $0) }
        if target == nil, newMode == .markdown {
            target = try? await createFile(at: "main.md", text: TemplateCatalog.markdownStarter)
        }
        build.requestBuild()
        return target
    }
}
