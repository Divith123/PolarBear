//
//  ManagedTool.swift
//  PolarBear
//

import Foundation

/// A command-line program PolarBear can download and install for the user, with one click: the TeX
/// engine to compile with, and the AI agent to talk to. Both come straight from the projects'
/// official GitHub releases.
nonisolated enum ManagedTool: String, CaseIterable, Identifiable, Sendable {
    case tectonic
    case openCode

    var id: String { rawValue }

    /// Product names, not localised.
    var displayName: String {
        switch self {
        case .tectonic: "Tectonic"
        case .openCode: "OpenCode"
        }
    }

    /// The program's file name.
    var executableName: String {
        switch self {
        case .tectonic: "tectonic"
        case .openCode: "opencode"
        }
    }

    /// `owner/name` on GitHub.
    var repository: String {
        switch self {
        case .tectonic: "tectonic-typesetting/tectonic"
        case .openCode: "anomalyco/opencode"
        }
    }

    /// How much is downloaded, roughly, so the user knows before clicking.
    var downloadSize: String {
        switch self {
        case .tectonic: "about 22 MB"
        case .openCode: "about 65 MB"
        }
    }

    /// The release asset for this Mac's processor, matched by the end of its name.
    func isAsset(named name: String) -> Bool {
        #if arch(arm64)
        let architecture = "arm64"
        #else
        let architecture = "x64"
        #endif
        switch self {
        case .tectonic:
            return name.hasSuffix(architecture == "arm64" ? "aarch64-apple-darwin.tar.gz" : "x86_64-apple-darwin.tar.gz")
        case .openCode:
            return name == "opencode-darwin-\(architecture).zip"
        }
    }

    /// The version in a release tag (`tectonic@0.17.0`, `v2.2.5`), if the tag belongs to a release of this program.
    func version(fromTag tag: String) -> String? {
        switch self {
        case .tectonic:
            return tag.hasPrefix("tectonic@") ? String(tag.dropFirst("tectonic@".count)) : nil
        case .openCode:
            guard tag.hasPrefix("v") else { return nil }
            let version = String(tag.dropFirst())
            return version.wholeMatch(of: /\d+\.\d+\.\d+/) != nil ? version : nil
        }
    }

    /// OpenCode 2 or later: the version PolarBear's adapter is written for.
    func isSupported(version: String) -> Bool {
        switch self {
        case .tectonic: true
        case .openCode: (Int(version.split(separator: ".").first ?? "") ?? 0) >= 2
        }
    }
}
