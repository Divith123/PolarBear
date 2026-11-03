//
//  ArchiveTool.swift
//  PolarBear
//

import Foundation

/// Zips and unpacks projects with the tools that ship with macOS (`zip`, `ditto`, `tar`).
nonisolated enum ArchiveTool {
    enum ArchiveError: LocalizedError {
        case failed(String)
        case unsupported(String)
        case unsafe(String)

        var errorDescription: String? {
            switch self {
            case .failed(let message): message
            case .unsupported(let name): String(localized: "“\(name)” is not a .zip, .tar.gz or .tgz archive.")
            case .unsafe(let entry): String(localized: "The archive contains an unsafe path (“\(entry)”) and was not opened.")
            }
        }
    }

    /// Writes the project folder to `destination`, leaving out PolarBear's own metadata and Git.
    @concurrent
    static func zip(folder: URL, to destination: URL) async throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destination.path(percentEncoded: false)) {
            try fileManager.removeItem(at: destination)
        }
        let result = try await ProcessRunner.run(
            executable: URL(filePath: "/usr/bin/zip"),
            arguments: [
                "-r", "-q", "-y", destination.path(percentEncoded: false), ".",
                "-x", "\(ProjectPaths.metadataFolderName)/*", "-x", ".git/*", "-x", "*.DS_Store",
            ],
            directory: folder,
            environment: ProcessEnvironment.make(extraPaths: [])
        )
        guard result.status == 0 else { throw ArchiveError.failed(result.output) }
    }

    /// Unpacks a `.zip`, `.tar.gz` or `.tgz` into the existing folder `destination`.
    @concurrent
    static func unpack(_ archive: URL, into destination: URL) async throws {
        try await validate(archive)

        let name = archive.lastPathComponent.lowercased()
        let executable: String
        let arguments: [String]
        if name.hasSuffix(".zip") {
            executable = "/usr/bin/ditto"
            arguments = ["-x", "-k", archive.path(percentEncoded: false), destination.path(percentEncoded: false)]
        } else if name.hasSuffix(".tar.gz") || name.hasSuffix(".tgz") || name.hasSuffix(".tar") {
            executable = "/usr/bin/tar"
            arguments = ["-xf", archive.path(percentEncoded: false), "-C", destination.path(percentEncoded: false)]
        } else {
            throw ArchiveError.unsupported(archive.lastPathComponent)
        }
        let result = try await ProcessRunner.run(
            executable: URL(filePath: executable),
            arguments: arguments,
            directory: destination,
            environment: ProcessEnvironment.make(extraPaths: [])
        )
        guard result.status == 0 else { throw ArchiveError.failed(result.output) }
    }

    /// Lists the archive and refuses it if any entry could land outside the target folder
    /// (an absolute path, or a `..` component).
    @concurrent
    static func validate(_ archive: URL) async throws {
        let name = archive.lastPathComponent.lowercased()
        let listing: (String, [String])
        if name.hasSuffix(".zip") {
            listing = ("/usr/bin/unzip", ["-Z1", archive.path(percentEncoded: false)])
        } else if name.hasSuffix(".tar.gz") || name.hasSuffix(".tgz") || name.hasSuffix(".tar") {
            listing = ("/usr/bin/tar", ["-tf", archive.path(percentEncoded: false)])
        } else {
            throw ArchiveError.unsupported(archive.lastPathComponent)
        }
        let result = try await ProcessRunner.run(
            executable: URL(filePath: listing.0),
            arguments: listing.1,
            directory: FileManager.default.temporaryDirectory,
            environment: ProcessEnvironment.make(extraPaths: [])
        )
        guard result.status == 0 else { throw ArchiveError.failed(result.output) }
        for entry in result.output.split(separator: "\n") {
            let path = String(entry)
            if path.hasPrefix("/") || path.split(separator: "/").contains("..") {
                throw ArchiveError.unsafe(path)
            }
        }
    }
}
