//
//  GitGraph.swift
//  PolarBear
//

import CoreGraphics
import Foundation

/// A Mermaid `gitGraph`: branches as horizontal lanes, commits as dots in the order they happen.
nonisolated struct GitGraph {
    struct Commit {
        var id: String
        var branch: Int
        var tag: String?
        var kind: String
        var isMerge: Bool
        /// Indexes of the commits this one follows.
        var parents: [Int]
    }

    var branches: [String] = ["main"]
    var commits: [Commit] = []

    static func parse(_ lines: [String]) -> GitGraph {
        var graph = GitGraph()
        var current = 0
        var heads: [Int: Int] = [:] // branch → latest commit
        var counter = 0

        func newID() -> String {
            let digits = String((counter &* 2_654_435_761 &+ 0x9E3779B) & 0xFFFFFFF, radix: 16)
            let hash = String(repeating: "0", count: max(0, 7 - digits.count)) + digits
            defer { counter += 1 }
            return "\(counter)-\(hash)"
        }
        func option(_ line: String, _ key: String) -> String? {
            guard let keyRange = line.range(of: key + ":") else { return nil }
            let rest = line[keyRange.upperBound...].drop(while: { $0 == " " })
            guard rest.first == "\"", let close = rest.dropFirst().firstIndex(of: "\"") else { return nil }
            return String(rest[rest.index(after: rest.startIndex)..<close])
        }

        for (offset, raw) in lines.enumerated() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("%%") || (offset == 0 && line.lowercased().hasPrefix("gitgraph")) { continue }

            if line.hasPrefix("commit") {
                var parents: [Int] = []
                if let head = heads[current] { parents.append(head) }
                let id = option(line, "id") ?? newID()
                let kind = line.firstMatch(of: /type:\s*(\w+)/).map { String($0.1) } ?? "NORMAL"
                graph.commits.append(Commit(id: id, branch: current, tag: option(line, "tag"), kind: kind, isMerge: false, parents: parents))
                heads[current] = graph.commits.count - 1
            } else if let match = line.prefixMatch(of: /^branch\s+(\S+)/) {
                let name = String(match.1)
                let source = heads[current]
                graph.branches.append(name)
                current = graph.branches.count - 1
                if let source { heads[current] = source }
            } else if let match = line.prefixMatch(of: /^(?:checkout|switch)\s+(\S+)/) {
                if let found = graph.branches.firstIndex(of: String(match.1)) { current = found }
            } else if let match = line.prefixMatch(of: /^merge\s+(\S+)/) {
                guard let other = graph.branches.firstIndex(of: String(match.1)) else { continue }
                var parents: [Int] = []
                if let head = heads[current] { parents.append(head) }
                if let otherHead = heads[other] { parents.append(otherHead) }
                graph.commits.append(Commit(id: option(line, "id") ?? newID(), branch: current, tag: option(line, "tag"), kind: "NORMAL", isMerge: true, parents: parents))
                heads[current] = graph.commits.count - 1
            }
        }
        return graph
    }

    func svg() -> String {
        guard !commits.isEmpty else { return "" }
        func n(_ value: Double) -> String { DiagramText.number(value) }
        let laneGap = 56.0, step = 78.0
        let labelWidth = (branches.map { DiagramText.width($0, size: 13, bold: true) }.max() ?? 0) + 30
        let left = labelWidth + 24
        let width = left + Double(commits.count) * step + 30
        let height = Double(branches.count) * laneGap + 90
        func point(of commit: Int) -> CGPoint {
            CGPoint(x: left + Double(commit) * step + step / 2, y: 44 + Double(commits[commit].branch) * laneGap)
        }

        var markup = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 \(n(width)) \(n(height))\" width=\"\(n(width))\" height=\"\(n(height))\" font-family=\"-apple-system, 'SF Pro Text', Helvetica, Arial, sans-serif\">\n"
        func colour(_ branch: Int) -> String { DiagramTheme.palette[branch % DiagramTheme.palette.count] }

        // Lane guides and labels.
        for (index, name) in branches.enumerated() {
            let y = 44 + Double(index) * laneGap
            markup += "<line x1=\"\(n(left - 8))\" y1=\"\(n(y))\" x2=\"\(n(width - 12))\" y2=\"\(n(y))\" stroke=\"\(colour(index))\" stroke-opacity=\"0.35\" stroke-width=\"1.5\" stroke-dasharray=\"3 6\"/>"
            let boxWidth = DiagramText.width(name, size: 13, bold: true) + 20
            markup += "<rect x=\"\(n(12))\" y=\"\(n(y - 14))\" width=\"\(n(boxWidth))\" height=\"28\" rx=\"6\" fill=\"\(colour(index))\" fill-opacity=\"0.16\" stroke=\"\(colour(index))\" stroke-width=\"1.5\"/>"
            markup += DiagramText.centred([name], at: CGPoint(x: 12 + boxWidth / 2, y: y), fontSize: 13, bold: true)
        }

        // Links between commits.
        for (index, commit) in commits.enumerated() {
            let to = point(of: index)
            for parent in commit.parents {
                let from = point(of: parent)
                let branch = commits[parent].branch == commit.branch ? commit.branch : (commit.isMerge && parent != commit.parents.first ? commits[parent].branch : commit.branch)
                if from.y == to.y {
                    markup += "<line x1=\"\(n(from.x))\" y1=\"\(n(from.y))\" x2=\"\(n(to.x))\" y2=\"\(n(to.y))\" stroke=\"\(colour(branch))\" stroke-width=\"4\"/>"
                } else {
                    let middle = (from.x + to.x) / 2
                    markup += "<path d=\"M\(n(from.x)),\(n(from.y)) C\(n(middle)),\(n(from.y)) \(n(middle)),\(n(to.y)) \(n(to.x)),\(n(to.y))\" fill=\"none\" stroke=\"\(colour(branch))\" stroke-width=\"4\"/>"
                }
            }
        }

        // Commits, labels and tags.
        for (index, commit) in commits.enumerated() {
            let p = point(of: index)
            let colour = colour(commit.branch)
            if commit.isMerge {
                markup += "<circle cx=\"\(n(p.x))\" cy=\"\(n(p.y))\" r=\"11\" fill=\"#ffffff\" stroke=\"\(colour)\" stroke-width=\"3\"/><circle cx=\"\(n(p.x))\" cy=\"\(n(p.y))\" r=\"5\" fill=\"\(colour)\"/>"
            } else if commit.kind.uppercased() == "HIGHLIGHT" {
                markup += "<rect x=\"\(n(p.x - 10))\" y=\"\(n(p.y - 10))\" width=\"20\" height=\"20\" fill=\"\(colour)\" stroke=\"#ffffff\" stroke-width=\"2\"/>"
            } else if commit.kind.uppercased() == "REVERSE" {
                markup += "<circle cx=\"\(n(p.x))\" cy=\"\(n(p.y))\" r=\"10\" fill=\"#ffffff\" stroke=\"\(colour)\" stroke-width=\"3\"/><path d=\"M\(n(p.x - 4)),\(n(p.y - 4)) L\(n(p.x + 4)),\(n(p.y + 4)) M\(n(p.x + 4)),\(n(p.y - 4)) L\(n(p.x - 4)),\(n(p.y + 4))\" stroke=\"\(colour)\" stroke-width=\"2\"/>"
            } else {
                markup += "<circle cx=\"\(n(p.x))\" cy=\"\(n(p.y))\" r=\"10\" fill=\"\(colour)\" stroke=\"#ffffff\" stroke-width=\"2.5\"/>"
            }
            markup += DiagramText.centred([commit.id], at: CGPoint(x: p.x, y: p.y + 26), fontSize: 11, fill: DiagramTheme.mutedText)
            if let tag = commit.tag {
                let tagWidth = DiagramText.width(tag, size: 11.5, bold: true) + 16
                markup += "<rect x=\"\(n(p.x - tagWidth / 2))\" y=\"\(n(p.y - 40))\" width=\"\(n(tagWidth))\" height=\"20\" rx=\"4\" fill=\"#fff8c5\" stroke=\"#d4a72c\" stroke-width=\"1.2\"/>"
                markup += DiagramText.centred([tag], at: CGPoint(x: p.x, y: p.y - 30), fontSize: 11.5, bold: true)
            }
        }
        return markup + "</svg>"
    }
}
