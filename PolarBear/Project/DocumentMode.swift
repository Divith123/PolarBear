//
//  DocumentMode.swift
//  PolarBear
//

import Foundation

/// What a project is written in. A TeX project is compiled by a TeX engine; a Markdown project
/// is rendered by PolarBear itself. Switching it changes the whole project: the editor's
/// language, the outline, the preview and the export and copy options.
nonisolated enum DocumentMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case tex
    case markdown

    var id: String { rawValue }

    /// Proper names, so they are not localised.
    var title: String {
        switch self {
        case .tex: "TeX"
        case .markdown: "Markdown"
        }
    }
}
