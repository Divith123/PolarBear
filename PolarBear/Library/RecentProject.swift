//
//  RecentProject.swift
//  PolarBear
//

import Foundation

/// A project the user opened before. The bookmark lets the app reopen the folder later even
/// when the system would otherwise forget the permission to access it.
struct RecentProject: Codable, Identifiable, Hashable {
    var path: String
    var name: String
    var bookmark: Data
    var lastOpened: Date

    var id: String { path }

    /// The folder's location with the home directory abbreviated (`~/Documents/Thesis`).
    var displayPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path(percentEncoded: false)
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }
}
