//
//  SourceLanguage.swift
//  PolarBear
//

/// How the editor colours a file.
nonisolated enum SourceLanguage: Sendable {
    case tex
    case markdown
    case plain

    init(kind: FileKind) {
        switch kind {
        case .tex: self = .tex
        case .markdown: self = .markdown
        case .bibliography, .plainText, .image, .pdf, .other: self = .plain
        }
    }
}
