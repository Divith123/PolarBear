//
//  ProjectAsset.swift
//  PolarBear
//

import Foundation

/// A project file the code editor cannot show (an image, a PDF, a font…).
struct ProjectAsset: Identifiable, Hashable {
    let path: String

    var id: String { path }

    var name: String {
        path.split(separator: "/").last.map(String.init) ?? path
    }

    var kind: FileKind {
        FileKind(path: path)
    }
}
