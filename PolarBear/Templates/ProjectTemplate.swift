//
//  ProjectTemplate.swift
//  PolarBear
//

import Foundation

/// A starting point for a new project.
struct ProjectTemplate: Identifiable, Hashable {
    let id: String
    let name: LocalizedStringResource
    let summary: LocalizedStringResource
    let symbol: String
    let files: [TemplateFile]

    static func == (lhs: ProjectTemplate, rhs: ProjectTemplate) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
