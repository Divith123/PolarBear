//
//  SecurityScope.swift
//  PolarBear
//

import Foundation

/// Keeps access to a user-chosen folder alive for as long as the object lives. (Needed under
/// the App Sandbox; harmless without it.)
nonisolated final class SecurityScope: @unchecked Sendable {
    private let url: URL
    private let started: Bool

    init(url: URL) {
        self.url = url
        self.started = url.startAccessingSecurityScopedResource()
    }

    deinit {
        if started { url.stopAccessingSecurityScopedResource() }
    }
}
