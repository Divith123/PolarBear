//
//  ImportPreview.swift
//  PolarBear
//

import Foundation

/// What an archive contains, shown before anything is added to the user's folders.
nonisolated struct ImportPreview: Sendable {
    /// Where the unpacked project waits until the user confirms.
    var content: URL
    /// The temporary folder to delete afterwards.
    var staging: URL
    var suggestedName: String
    var fileCount: Int
    var rootFile: String?
    /// Packages the document asks for.
    var packages: [String]
    /// Packages the installed TeX distribution lacks; `nil` when it cannot tell.
    var missingPackages: [String]?
    var warnings: [String]
}
