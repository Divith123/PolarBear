//
//  ToolInstallError.swift
//  PolarBear
//

import Foundation

/// Why installing a tool failed, in words the user can act on.
nonisolated enum ToolInstallError: LocalizedError {
    case offline(String)
    case noRelease(ManagedTool)
    case noChecksum(String)
    case badDownload(String)
    case checksumMismatch
    case missingProgram(String)
    case wouldNotRun(String)

    var errorDescription: String? {
        switch self {
        case .offline(let reason):
            String(localized: "Could not reach GitHub: \(reason)")
        case .noRelease(let tool):
            String(localized: "No release of \(tool.displayName) for this Mac was found.")
        case .noChecksum(let name):
            String(localized: "GitHub published no checksum for \(name), so it was not installed.")
        case .badDownload(let reason):
            String(localized: "The download failed: \(reason)")
        case .checksumMismatch:
            String(localized: "The downloaded file does not match its checksum, so it was thrown away.")
        case .missingProgram(let name):
            String(localized: "The download did not contain \(name).")
        case .wouldNotRun(let reason):
            String(localized: "The program was installed but would not start: \(reason)")
        }
    }
}
