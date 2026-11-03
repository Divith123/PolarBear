//
//  ProjectPath.swift
//  PolarBear
//

import Foundation

/// String helpers for project-relative paths (always `/`-separated, never absolute).
nonisolated enum ProjectPath {
    static func name(of path: String) -> String {
        path.split(separator: "/").last.map(String.init) ?? path
    }

    /// The containing folder, or `""` at the top level.
    static func parent(of path: String) -> String {
        path.split(separator: "/").dropLast().joined(separator: "/")
    }

    static func join(_ folder: String, _ name: String) -> String {
        folder.isEmpty ? name : folder + "/" + name
    }

    static func stem(of path: String) -> String {
        let name = name(of: path)
        guard let dot = name.lastIndex(of: "."), dot != name.startIndex else { return name }
        return String(name[..<dot])
    }

    static func fileExtension(of path: String) -> String {
        let name = name(of: path)
        guard let dot = name.lastIndex(of: "."), dot != name.startIndex else { return "" }
        return String(name[name.index(after: dot)...])
    }

    /// `path`, or `stem 2.ext`, `stem 3.ext`, … when `isTaken` says it is in use.
    static func unique(_ path: String, isTaken: (String) -> Bool) -> String {
        guard isTaken(path) else { return path }
        let folder = parent(of: path)
        let stem = stem(of: path)
        let fileExtension = fileExtension(of: path)
        var counter = 2
        while true {
            let name = fileExtension.isEmpty ? "\(stem) \(counter)" : "\(stem) \(counter).\(fileExtension)"
            let candidate = join(folder, name)
            if !isTaken(candidate) { return candidate }
            counter += 1
        }
    }

    /// Every folder that contains `path`, outermost first (`a/b/c.tex` → `a`, `a/b`).
    static func ancestors(of path: String) -> [String] {
        let components = path.split(separator: "/").dropLast()
        return components.indices.map { index in
            components[components.startIndex...index].joined(separator: "/")
        }
    }

    /// Makes a user-typed name safe: no path separators, trimmed, `.tex` when it has no extension.
    static func sanitisedFileName(_ raw: String, defaultExtension: String? = "tex") -> String {
        var name = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacing("/", with: "-")
            .replacing(":", with: "-")
        guard !name.isEmpty else { return "" }
        if let defaultExtension, !name.dropFirst().contains(".") { name += "." + defaultExtension }
        return name
    }
}
