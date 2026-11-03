//
//  FilePrompt.swift
//  PolarBear
//

import Foundation

/// A question the window asks about a file name.
enum FilePrompt: Identifiable, Equatable {
    case newFile(folder: String)
    case newFolder(parent: String)
    case rename(path: String)

    var id: String {
        switch self {
        case .newFile(let folder): "new-file:\(folder)"
        case .newFolder(let parent): "new-folder:\(parent)"
        case .rename(let path): "rename:\(path)"
        }
    }
}
