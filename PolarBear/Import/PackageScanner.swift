//
//  PackageScanner.swift
//  PolarBear
//

import Foundation

/// Finds the LaTeX packages and classes a document loads.
nonisolated enum PackageScanner {
    static func packages(in text: String) -> [String] {
        var names: [String] = []
        for line in text.split(separator: "\n") {
            let trimmed = line.drop(while: { $0 == " " || $0 == "\t" })
            guard !trimmed.hasPrefix("%") else { continue }
            for match in trimmed.matches(of: /\\(?:usepackage|RequirePackage)(?:\[[^\]]*\])?\{([^}]*)\}/) {
                names += match.1.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            }
        }
        var seen: Set<String> = []
        return names.filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    /// The packages `kpsewhich` cannot find (`.sty` files). Local packages shipped inside the
    /// project are not counted as missing.
    @concurrent
    static func missing(_ packages: [String], using kpsewhich: URL, projectFiles: Set<String>) async -> [String] {
        var missing: [String] = []
        for package in packages where !projectFiles.contains(package + ".sty") {
            let result = try? await ProcessRunner.run(
                executable: kpsewhich,
                arguments: [package + ".sty"],
                directory: FileManager.default.temporaryDirectory,
                environment: ProcessEnvironment.make(extraPaths: [kpsewhich.deletingLastPathComponent()])
            )
            if result?.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
                missing.append(package)
            }
        }
        return missing
    }
}
