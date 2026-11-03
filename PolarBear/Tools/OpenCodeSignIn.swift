//
//  OpenCodeSignIn.swift
//  PolarBear
//

import SwiftUI

/// OpenCode asks for its login in a terminal, so "Sign In" opens Terminal running
/// `opencode auth login` (PolarBear never sees what is typed there).
enum OpenCodeSignIn {
    static func open(executable: URL) {
        let script = """
        #!/bin/zsh
        clear
        echo "Connecting OpenCode to an AI provider…"
        echo
        \(quoted(executable.path(percentEncoded: false))) auth login
        echo
        echo "Done. You can close this window and go back to PolarBear."
        """
        let folder = FileManager.default.temporaryDirectory.appending(path: "PolarBearSignIn-\(UUID().uuidString)", directoryHint: .isDirectory)
        let file = folder.appending(path: "OpenCode Sign In.command")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try Data(script.utf8).write(to: file)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: file.path(percentEncoded: false))
            NSWorkspace.shared.open(file)
        } catch {
            NSWorkspace.shared.open(URL(filePath: "/System/Applications/Utilities/Terminal.app"))
        }
    }

    /// A path as one shell word.
    private static func quoted(_ text: String) -> String {
        "'" + text.replacing("'", with: "'\\''") + "'"
    }
}
