//
//  ToolRelease.swift
//  PolarBear
//

import Foundation

/// A downloadable release of a `ManagedTool`.
nonisolated struct ToolRelease: Sendable {
    var version: String
    var assetName: String
    var downloadURL: URL
    /// The SHA-256 GitHub computed for the file, in hexadecimal.
    var sha256: String
}
