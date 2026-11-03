//
//  ProcessEnvironment.swift
//  PolarBear
//

import Foundation

/// The environment given to child processes: the app's own, with the tool folders added to
/// `PATH` (a Mac app starts without the shell's search path).
nonisolated enum ProcessEnvironment {
    static func make(extraPaths: [URL], extra: [String: String] = [:]) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let inherited = environment["PATH"]?.split(separator: ":").map(String.init) ?? []
        let combined = extraPaths.map { $0.path(percentEncoded: false) }
            + inherited + ["/usr/bin", "/bin", "/usr/sbin", "/sbin"]

        var seen: Set<String> = []
        environment["PATH"] = combined.filter { seen.insert($0).inserted }.joined(separator: ":")
        environment["TERM"] = "dumb"
        if environment["LANG"] == nil { environment["LANG"] = "en_US.UTF-8" }
        for (key, value) in extra { environment[key] = value }
        return environment
    }
}
