//
//  FlowchartParser.swift
//  PolarBear
//

import CoreGraphics
import Foundation

/// Parses Mermaid `graph` / `flowchart` text.
nonisolated enum FlowchartParser {
    static func parse(_ lines: [String]) -> FlowGraph {
        var graph = FlowGraph()
        var stack: [String] = []
        var anonymous = 0

        for (offset, raw) in lines.enumerated() {
            for statement in splitStatements(raw) {
                let line = statement.trimmingCharacters(in: .whitespaces)
                if line.isEmpty || line.hasPrefix("%%") { continue }

                if offset == 0, let header = line.prefixMatch(of: /^(?:graph|flowchart(?:-elk)?)\s*([A-Za-z]{2})?\s*$/.ignoresCase()) {
                    if let direction = header.1 { graph.direction = GraphLayout.Direction(String(direction)) }
                    continue
                }
                if line.lowercased() == "end" {
                    _ = stack.popLast()
                    continue
                }
                if line.lowercased().hasPrefix("subgraph") {
                    anonymous += 1
                    let (id, title) = subgraphHeader(String(line.dropFirst(8)), fallback: "subgraph\(anonymous)")
                    graph.subgraphs.append(FlowGraph.Subgraph(id: id, title: title, parent: stack.last))
                    stack.append(id)
                    continue
                }
                if line.lowercased().hasPrefix("direction ") { continue }
                if let match = line.prefixMatch(of: /^classDef\s+(\S+)\s+(.+)$/) {
                    let properties = styleProperties(String(match.2))
                    for name in match.1.split(separator: ",") { graph.classes[String(name)] = properties }
                    continue
                }
                if let match = line.prefixMatch(of: /^class\s+(\S+)\s+(\S+)\s*$/) {
                    for id in match.1.split(separator: ",") {
                        if let index = graph.index(of: String(id)) { graph.nodes[index].className = String(match.2) }
                    }
                    continue
                }
                if let match = line.prefixMatch(of: /^style\s+(\S+)\s+(.+)$/) {
                    for id in match.1.split(separator: ",") {
                        if let index = graph.index(of: String(id)) {
                            graph.nodes[index].style.merge(styleProperties(String(match.2))) { $1 }
                        }
                    }
                    continue
                }
                if line.hasPrefix("linkStyle") || line.hasPrefix("click ") || line.hasPrefix("accTitle") || line.hasPrefix("accDescr") { continue }

                var scanner = Scanner(Array(line), graph: graph, scope: stack.last)
                scanner.parseChain()
                graph = scanner.graph
            }
        }
        return graph
    }

    /// Statements may share a line when separated by `;`.
    private static func splitStatements(_ line: String) -> [String] {
        var parts: [String] = []
        var current = ""
        var inQuote = false
        for character in line {
            if character == "\"" { inQuote.toggle() }
            if character == ";", !inQuote {
                parts.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        parts.append(current)
        return parts
    }

    private static func subgraphHeader(_ text: String, fallback: String) -> (id: String, title: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if let match = trimmed.prefixMatch(of: /^([A-Za-z0-9_]+)\s*\[\s*"?(.*?)"?\s*\]\s*$/) {
            return (String(match.1), String(match.2))
        }
        let title = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        let id = title.contains(" ") || title.isEmpty ? fallback : title
        return (id, title.isEmpty ? fallback : title)
    }

    static func styleProperties(_ text: String) -> [String: String] {
        var result: [String: String] = [:]
        for pair in text.split(separator: ",") {
            let parts = pair.split(separator: ":", maxSplits: 1)
            if parts.count == 2 { result[parts[0].trimmingCharacters(in: .whitespaces)] = parts[1].trimmingCharacters(in: .whitespaces) }
        }
        return result
    }

    // MARK: Scanner

    private struct Scanner {
        let characters: [Character]
        var graph: FlowGraph
        let scope: String?
        var index = 0

        init(_ characters: [Character], graph: FlowGraph, scope: String?) {
            self.characters = characters
            self.graph = graph
            self.scope = scope
        }

        var remaining: String { String(characters[index...]) }

        mutating func skipSpaces() {
            while index < characters.count, characters[index] == " " || characters[index] == "\t" { index += 1 }
        }

        mutating func parseChain() {
            guard var left = parseGroup() else { return }
            while true {
                skipSpaces()
                guard index < characters.count, let edge = parseEdgeOperator() else { break }
                guard let right = parseGroup() else { break }
                for from in left {
                    for to in right {
                        graph.edges.append(FlowGraph.Edge(from: from, to: to, label: edge.label, style: edge.style, head: edge.head, tail: edge.tail))
                    }
                }
                left = right
            }
        }

        /// `A`, `A[text]`, or `A & B & C`.
        mutating func parseGroup() -> [String]? {
            var ids: [String] = []
            while true {
                skipSpaces()
                guard let id = parseNode() else { break }
                ids.append(id)
                skipSpaces()
                if index < characters.count, characters[index] == "&" {
                    index += 1
                    continue
                }
                break
            }
            return ids.isEmpty ? nil : ids
        }

        mutating func parseNode() -> String? {
            let start = index
            while index < characters.count, isIdentifierCharacter(characters[index]) { index += 1 }
            guard index > start else { return nil }
            let id = String(characters[start..<index])

            var label: String?
            var shape: FlowGraph.Shape?
            if let parsed = parseShape() {
                label = parsed.label
                shape = parsed.shape
            }
            let nodeIndex = graph.addNode(id: id, label: label, shape: shape)
            if index + 2 < characters.count, characters[index] == ":", characters[index + 1] == ":", characters[index + 2] == ":" {
                index += 3
                let classStart = index
                while index < characters.count, isIdentifierCharacter(characters[index]) { index += 1 }
                graph.nodes[nodeIndex].className = String(characters[classStart..<index])
            }
            if let scope, let position = graph.subgraphs.firstIndex(where: { $0.id == scope }),
               !graph.subgraphs[position].members.contains(id) {
                graph.subgraphs[position].members.append(id)
            }
            return id
        }

        func isIdentifierCharacter(_ character: Character) -> Bool {
            character.isLetter || character.isNumber || character == "_"
        }

        private static let shapes: [(open: String, close: String, shape: FlowGraph.Shape)] = [
            ("(((", ")))", .doubleCircle), ("((", "))", .circle), ("([", "])", .stadium), ("(", ")", .rounded),
            ("[[", "]]", .subroutine), ("[(", ")]", .cylinder), ("[/", "/]", .parallelogram), ("[\\", "\\]", .parallelogramAlt),
            ("[/", "\\]", .trapezoid), ("[\\", "/]", .trapezoidAlt), ("[", "]", .rectangle),
            ("{{", "}}", .hexagon), ("{", "}", .diamond), (">", "]", .asymmetric),
        ]

        mutating func parseShape() -> (label: String, shape: FlowGraph.Shape)? {
            let rest = remaining
            // `[/…\]` and `[\…/]` share their opening with the parallelograms: choose by the closing.
            for candidate in Self.shapes where rest.hasPrefix(candidate.open) {
                let body = rest.dropFirst(candidate.open.count)
                var text = ""
                var quoted = false
                var cursor = body.startIndex
                if body.first == "\"" {
                    quoted = true
                    cursor = body.index(after: cursor)
                    guard let close = body[cursor...].firstIndex(of: "\"") else { continue }
                    text = String(body[cursor..<close])
                    cursor = body.index(after: close)
                    let afterQuote = body[cursor...].drop(while: { $0 == " " })
                    guard afterQuote.hasPrefix(candidate.close) else { continue }
                    let consumed = rest.count - afterQuote.count + candidate.close.count
                    index += consumed
                    return (text, candidate.shape)
                }
                _ = quoted
                guard let range = body.range(of: candidate.close) else { continue }
                text = String(body[..<range.lowerBound])
                index += candidate.open.count + text.count + candidate.close.count
                return (text.trimmingCharacters(in: .whitespaces), candidate.shape)
            }
            return nil
        }

        struct EdgeOperator {
            var label: String?
            var style = FlowGraph.LineStyle.solid
            var head = FlowGraph.Ending.arrow
            var tail = FlowGraph.Ending.none
        }

        mutating func parseEdgeOperator() -> EdgeOperator? {
            let rest = remaining

            // `-- text -->`, `== text ==>`, `-. text .->`
            if let match = rest.prefixMatch(of: /^(<)?(--|==|-\.)\s+(.+?)\s+(-{2,}>|-{3,}|-{2,}[ox](?=\s)|={2,}>|={3,}|\.-+>|\.-)(?=\s|$)/) {
                var edge = EdgeOperator(label: String(match.3).trimmingCharacters(in: CharacterSet(charactersIn: "\"")))
                edge.tail = match.1 != nil ? .arrow : .none
                let closer = String(match.4)
                edge.style = closer.hasPrefix("=") ? .thick : (closer.hasPrefix(".") ? .dotted : .solid)
                edge.head = closer.hasSuffix(">") ? .arrow : (closer.hasSuffix("o") ? .circle : (closer.hasSuffix("x") ? .cross : .none))
                index += match.0.count
                return edge
            }

            guard let match = rest.prefixMatch(of: /^(<|o|x)?(-{2,}|={2,}|-\.+-|~{3,})(>|o(?=\s)|x(?=\s))?/) else { return nil }
            var edge = EdgeOperator()
            let body = String(match.2)
            let ending = match.3.map(String.init)
            if body.hasPrefix("~") {
                edge.style = .invisible
                edge.head = .none
            } else {
                edge.style = body.hasPrefix("=") ? .thick : (body.contains(".") ? .dotted : .solid)
                switch ending {
                case ">": edge.head = .arrow
                case "o": edge.head = .circle
                case "x": edge.head = .cross
                default:
                    guard body.count >= 3 else { return nil } // `--` alone is not an edge
                    edge.head = .none
                }
            }
            if let start = match.1 {
                edge.tail = start == "<" ? .arrow : (start == "o" ? .circle : .cross)
            }
            index += match.0.count

            // `|label|` right after the operator.
            let afterOperator = remaining
            if let label = afterOperator.prefixMatch(of: /^\s*\|([^|]*)\|/) {
                edge.label = String(label.1).trimmingCharacters(in: CharacterSet(charactersIn: "\" "))
                index += label.0.count
            }
            return edge
        }
    }
}
