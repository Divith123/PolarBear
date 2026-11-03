//
//  URL+ProjectKey.swift
//  PolarBear
//

import Foundation

extension URL {
    /// The folder's path without a trailing slash — the same string wherever the project is named
    /// (recent projects, open windows, preview windows).
    nonisolated var projectKey: String {
        var path = resolvingSymlinksInPath().path(percentEncoded: false)
        while path.count > 1, path.hasSuffix("/") { path.removeLast() }
        return path
    }
}
