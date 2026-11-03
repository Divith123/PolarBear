//
//  ToolInstallation.swift
//  PolarBear
//

import Foundation
import os

/// The steps of installing a `ManagedTool`: find the release, download it, check it, unpack it,
/// try it, put it in place.
nonisolated enum ToolInstallation {
    enum Step: Sendable {
        case lookingUp
        case downloading(Double)
        case checking
        case unpacking
        case testing
    }

    /// Installs the newest release and returns the program's location.
    @concurrent
    static func run(_ tool: ManagedTool, step: @escaping @Sendable (Step) -> Void) async throws -> URL {
        step(.lookingUp)
        let release = try await ToolReleaseFinder.latest(for: tool)

        step(.downloading(0))
        let archive = try await ToolDownloader.download(release.downloadURL, named: release.assetName) { step(.downloading($0)) }
        defer { try? FileManager.default.removeItem(at: archive.deletingLastPathComponent()) }

        step(.checking)
        guard try await ToolDownloader.sha256(of: archive) == release.sha256 else { throw ToolInstallError.checksumMismatch }

        step(.unpacking)
        let unpacked = archive.deletingLastPathComponent().appending(path: "unpacked", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: unpacked, withIntermediateDirectories: true)
        try await ArchiveTool.unpack(archive, into: unpacked)
        let program = unpacked.appending(path: tool.executableName)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: program.path(percentEncoded: false), isDirectory: &isDirectory), !isDirectory.boolValue else {
            throw ToolInstallError.missingProgram(tool.executableName)
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: program.path(percentEncoded: false))

        step(.testing)
        let result: ProcessRunner.Result
        do {
            result = try await ProcessRunner.run(
                executable: program, arguments: ["--version"], directory: FileManager.default.temporaryDirectory,
                environment: ProcessEnvironment.make(extraPaths: [])
            )
        } catch let error as ProcessRunner.LaunchError {
            throw ToolInstallError.wouldNotRun(error.message)
        }
        guard result.status == 0 else { throw ToolInstallError.wouldNotRun(String(result.output.prefix(200))) }

        let installed = try ToolStore.install(program, tool: tool, version: release.version)
        Log.build.info("Installed \(tool.displayName, privacy: .public) \(release.version, privacy: .public) at \(installed.path(percentEncoded: false), privacy: .public)")
        return installed
    }
}
