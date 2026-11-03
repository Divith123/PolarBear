//
//  FileKind.swift
//  PolarBear
//

import Foundation

/// What a project file is, decided by its extension.
nonisolated enum FileKind: Sendable {
    case tex
    case markdown
    case bibliography
    case plainText
    case image
    case pdf
    case other

    private static let texExtensions: Set<String> = [
        "tex", "sty", "cls", "ltx", "dtx", "ins", "def", "cfg", "clo", "fd", "bbx", "cbx", "lbx", "tikz", "pgf",
    ]
    private static let markdownExtensions: Set<String> = ["md", "markdown", "mdown", "mkd"]
    private static let bibliographyExtensions: Set<String> = ["bib", "bst"]
    private static let plainExtensions: Set<String> = [
        "txt", "csv", "tsv", "json", "yaml", "yml", "toml", "py", "sh", "r", "lua",
    ]
    private static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "svg", "eps", "tif", "tiff", "heic", "webp", "bmp",
    ]
    /// Files LaTeX writes next to the sources; they are not part of the project the user edits.
    private static let generatedExtensions: Set<String> = [
        "aux", "log", "toc", "lof", "lot", "out", "fls", "fdb_latexmk", "bbl", "blg", "bcf", "nav", "snm", "vrb",
        "xdv", "idx", "ilg", "ind", "glo", "gls", "glg", "acn", "acr", "alg", "synctex",
    ]

    init(path: String) {
        let name = path.split(separator: "/").last.map(String.init)?.lowercased() ?? path.lowercased()
        let fileExtension = name.split(separator: ".").last.map(String.init) ?? ""
        if Self.texExtensions.contains(fileExtension) {
            self = .tex
        } else if Self.markdownExtensions.contains(fileExtension) {
            self = .markdown
        } else if Self.bibliographyExtensions.contains(fileExtension) {
            self = .bibliography
        } else if Self.plainExtensions.contains(fileExtension) {
            self = .plainText
        } else if Self.imageExtensions.contains(fileExtension) {
            self = .image
        } else if fileExtension == "pdf" {
            self = .pdf
        } else {
            self = .other
        }
    }

    /// Opens in the code editor.
    var isText: Bool {
        switch self {
        case .tex, .markdown, .bibliography, .plainText: true
        case .image, .pdf, .other: false
        }
    }

    /// Changing it can change the PDF of a project in `mode`.
    func isBuildInput(in mode: DocumentMode) -> Bool {
        switch (mode, self) {
        case (.tex, .tex), (.tex, .bibliography), (.tex, .image), (.tex, .pdf): true
        case (.markdown, .markdown), (.markdown, .image): true
        default: false
        }
    }

    /// Whether the sidebar should list a file with this name at all.
    static func isGenerated(name: String) -> Bool {
        let lowered = name.lowercased()
        if lowered.hasSuffix(".synctex.gz") || lowered.hasSuffix(".run.xml") { return true }
        guard let fileExtension = lowered.split(separator: ".").last, lowered.contains(".") else { return false }
        return generatedExtensions.contains(String(fileExtension))
    }
}
