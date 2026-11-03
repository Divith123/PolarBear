//
//  ProcessTree.swift
//  PolarBear
//

import Darwin
import Foundation

/// Finds and stops a process together with everything it started (a compile runs
/// latexmk → pdflatex → bibtex …, and stopping only the first would leave the rest running).
nonisolated enum ProcessTree {
    static func children(of pid: pid_t) -> [pid_t] {
        var capacity = 64
        while true {
            var buffer = [pid_t](repeating: 0, count: capacity)
            let result = proc_listchildpids(pid, &buffer, Int32(capacity * MemoryLayout<pid_t>.size))
            guard result > 0 else { return [] }
            let found = buffer.prefix { $0 > 0 }
            if found.count < capacity { return Array(found) }
            capacity *= 2
        }
    }

    /// Every process below `root`, deepest first.
    static func descendants(of root: pid_t) -> [pid_t] {
        var levels: [[pid_t]] = []
        var current = [root]
        while true {
            let next = current.flatMap(children(of:))
            if next.isEmpty { break }
            levels.append(next)
            current = next
        }
        return levels.reversed().flatMap { $0 }
    }

    /// Asks the whole tree to stop, and force-kills what is still alive shortly after.
    static func terminate(_ root: pid_t) {
        let tree = descendants(of: root) + [root]
        for pid in tree {
            kill(pid, SIGTERM)
        }
        Task.detached {
            do {
                try await Task.sleep(for: .milliseconds(700))
            } catch {
                return
            }
            for pid in tree where kill(pid, 0) == 0 {
                kill(pid, SIGKILL)
            }
        }
    }
}
