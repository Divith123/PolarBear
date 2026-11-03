//
//  HistorySource.swift
//  PolarBear
//

import Foundation

/// A file's text at the moment a version is recorded.
nonisolated struct HistorySource: Sendable {
    var path: String
    var text: String
}
