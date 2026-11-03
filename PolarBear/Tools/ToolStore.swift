//
//  ToolStore.swift
//  PolarBear
//

import Foundation

/// Where the programs PolarBear installed live:
///
///     ~/Library/Application Support/PolarBear/Tools/
///         bin/tectonic            a link to the current version
///         tectonic/0.17.0/tectonic
///         opencode/2.2.5/opencode
nonisolated enum ToolStore {
    static var root: URL {
        URL.applicationSupportDirectory.appending(path: "PolarBear/Tools", directoryHint: .isDirectory)
    }

    /// The folder `ToolLocator` searches first.
    static var binDirectory: URL {
        root.appending(path: "bin", directoryHint: .isDirectory)
    }

    /// The installed program, if PolarBear installed one.
    static func executable(for tool: ManagedTool) -> URL? {
        let link = binDirectory.appending(path: tool.executableName)
        return FileManager.default.isExecutableFile(atPath: link.path(percentEncoded: false)) ? link : nil
    }

    /// Whether `url` is a program PolarBear installed (rather than one found elsewhere on the Mac).
    static func isManaged(_ url: URL) -> Bool {
        url.path(percentEncoded: false).hasPrefix(root.path(percentEncoded: false))
    }

    /// Puts the downloaded program in place and makes it the current one; older versions are deleted.
    static func install(_ program: URL, tool: ManagedTool, version: String) throws -> URL {
        let fileManager = FileManager.default
        let versionFolder = root.appending(path: "\(tool.executableName)/\(version)", directoryHint: .isDirectory)
        try? fileManager.removeItem(at: versionFolder)
        try fileManager.createDirectory(at: versionFolder, withIntermediateDirectories: true)
        let destination = versionFolder.appending(path: tool.executableName)
        try fileManager.moveItem(at: program, to: destination)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destination.path(percentEncoded: false))

        try fileManager.createDirectory(at: binDirectory, withIntermediateDirectories: true)
        let link = binDirectory.appending(path: tool.executableName)
        try? fileManager.removeItem(at: link)
        try fileManager.createSymbolicLink(atPath: link.path(percentEncoded: false), withDestinationPath: "../\(tool.executableName)/\(version)/\(tool.executableName)")

        let toolFolder = versionFolder.deletingLastPathComponent()
        for older in (try? fileManager.contentsOfDirectory(atPath: toolFolder.path(percentEncoded: false))) ?? [] where older != version {
            try? fileManager.removeItem(at: toolFolder.appending(path: older))
        }
        return link
    }

    static func remove(_ tool: ManagedTool) {
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: binDirectory.appending(path: tool.executableName))
        try? fileManager.removeItem(at: root.appending(path: tool.executableName, directoryHint: .isDirectory))
    }
}
