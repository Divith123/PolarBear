//
//  LineSplitter.swift
//  PolarBear
//

import Foundation

/// Turns the chunks a process prints into whole lines (a chunk can end in the middle of one).
nonisolated struct LineSplitter: Sendable {
    private var buffer = ""

    mutating func feed(_ chunk: String) -> [String] {
        buffer += chunk
        var lines = buffer.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        buffer = lines.removeLast()
        return lines
    }

    /// The unfinished last line, once the process has ended.
    mutating func flush() -> String? {
        defer { buffer = "" }
        return buffer.isEmpty ? nil : buffer
    }
}
