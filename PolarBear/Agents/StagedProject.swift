//
//  StagedProject.swift
//  PolarBear
//

import Foundation

/// A temporary copy of the project's text files in which an agent works. Nothing it does
/// reaches the real files until the user keeps a change.
nonisolated struct StagedProject: Sendable {
    /// The temporary folder to delete afterwards.
    var container: URL
    /// The folder the agent runs in.
    var root: URL
    /// The text of every file when the copy was made, by project-relative path.
    var baseline: [String: String]
    /// Configuration files written for the agent; they are not part of any change.
    var extras: Set<String>
}
