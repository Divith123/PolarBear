//
//  TemplateFile.swift
//  PolarBear
//

import Foundation

/// A file a new project starts with.
nonisolated struct TemplateFile: Hashable, Sendable {
    var path: String
    var text: String
}
