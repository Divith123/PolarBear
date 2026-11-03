//
//  FileStamp.swift
//  PolarBear
//

import Foundation

/// Cheap fingerprint of a file on disk (modification time and size), used to skip re-reading
/// files that did not change.
nonisolated struct FileStamp: Equatable, Sendable {
    var modified: Date
    var size: Int

    static let none = FileStamp(modified: .distantPast, size: -1)
}
