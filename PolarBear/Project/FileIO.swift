//
//  FileIO.swift
//  PolarBear
//

import Foundation

/// Reading and writing text files with their original encoding and line endings. Writes are
/// atomic (temp file + rename), so a crash never leaves a half-written file behind.
nonisolated enum FileIO {
    struct DecodedText: Sendable {
        var text: String
        var encoding: String.Encoding
        var usesCRLF: Bool
    }

    enum WriteError: Error {
        case notEncodable
    }

    /// UTF-8 first, then Latin-1 (which accepts any byte sequence). Line endings are
    /// normalised to `\n`; `usesCRLF` remembers the original style.
    static func decode(_ data: Data) -> DecodedText {
        var encoding = String.Encoding.utf8
        var text: String
        if let utf8 = String(data: data, encoding: .utf8) {
            text = utf8
        } else {
            encoding = .isoLatin1
            text = String(data: data, encoding: .isoLatin1) ?? ""
        }
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }

        let usesCRLF = text.contains("\r\n")
        if usesCRLF { text = text.replacing("\r\n", with: "\n") }
        return DecodedText(text: text, encoding: encoding, usesCRLF: usesCRLF)
    }

    /// The fingerprint of the file at `url`, if it exists.
    static func stamp(of url: URL) -> FileStamp? {
        guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]) else {
            return nil
        }
        return FileStamp(modified: values.contentModificationDate ?? .distantPast, size: values.fileSize ?? 0)
    }

    /// Writes `text` atomically and returns the new fingerprint.
    @concurrent
    static func write(_ text: String, encoding: String.Encoding, to url: URL) async throws -> FileStamp {
        guard let data = text.data(using: encoding) else { throw WriteError.notEncodable }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        return stamp(of: url) ?? .none
    }

    /// Reads a text file; `nil` when it cannot be read.
    @concurrent
    static func read(_ url: URL) async -> DecodedText? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return decode(data)
    }
}
