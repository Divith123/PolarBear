//
//  ToolLocator.swift
//  PolarBear
//

import Foundation

/// Finds command-line tools in the places they are usually installed. A Mac app does not
/// inherit the shell's `PATH`, so the usual folders are probed explicitly.
nonisolated enum ToolLocator {
    /// The first executable called `name` in `directories`.
    static func find(_ name: String, in directories: [URL]) -> URL? {
        for directory in directories {
            let candidate = directory.appending(path: name)
            if FileManager.default.isExecutableFile(atPath: candidate.path(percentEncoded: false)) {
                return candidate
            }
        }
        return nil
    }

    /// Where TeX distributions and Tectonic install their programs.
    static func texDirectories() -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        var directories = [
            ToolStore.binDirectory,
            URL(filePath: "/Library/TeX/texbin"),
            URL(filePath: "/opt/homebrew/bin"),
            URL(filePath: "/usr/local/bin"),
            URL(filePath: "/opt/local/bin"),
        ]
        directories += subfolders(of: URL(filePath: "/usr/local/texlive"), then: "bin")
        directories += subfolders(of: home.appending(path: "Library/TinyTeX"), then: "bin")
        directories += [home.appending(path: ".cargo/bin"), home.appending(path: "bin")]
        return directories
    }

    /// Where command-line agents usually live (Homebrew, npm, Bun, nvm, Volta, …).
    static func agentDirectories() -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        var directories = [
            ToolStore.binDirectory,
            URL(filePath: "/opt/homebrew/bin"),
            URL(filePath: "/usr/local/bin"),
            URL(filePath: "/opt/local/bin"),
        ]
        let relative = [
            "bin", ".local/bin", ".npm-global/bin", ".bun/bin", ".volta/bin", ".opencode/bin",
            ".claude/local", ".asdf/shims", ".local/share/mise/shims", ".cargo/bin",
        ]
        directories += relative.map { home.appending(path: $0) }
        directories += subfolders(of: home.appending(path: ".nvm/versions/node"), then: "bin")
        directories += subfolders(of: home.appending(path: ".local/share/fnm/node-versions"), then: "installation/bin")
        return directories
    }

    private static func subfolders(of parent: URL, then child: String) -> [URL] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: parent.path(percentEncoded: false))) ?? []
        return names.sorted(by: >).flatMap { name -> [URL] in
            let base = parent.appending(path: name)
            // TeX Live nests one more level: <year>/bin/<platform>.
            if child == "bin", parent.lastPathComponent == "texlive" {
                let platforms = (try? FileManager.default.contentsOfDirectory(atPath: base.appending(path: "bin").path(percentEncoded: false))) ?? []
                return platforms.sorted().map { base.appending(path: "bin").appending(path: $0) }
            }
            return [base.appending(path: child)]
        }
    }
}
