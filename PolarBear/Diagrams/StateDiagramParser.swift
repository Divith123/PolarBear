//
//  StateDiagramParser.swift
//  PolarBear
//

import CoreGraphics
import Foundation

/// Parses Mermaid `stateDiagram` text into a `FlowGraph`.
nonisolated enum StateDiagramParser {
    static func parse(_ lines: [String]) -> FlowGraph {
        var graph = FlowGraph()
        var stack: [String] = [] // composite states being defined
        var startCount = 0, endCount = 0

        func scopePrefix() -> String { stack.joined(separator: ".") }
        func qualified(_ id: String) -> String { stack.isEmpty ? id : scopePrefix() + "." + id }

        func register(_ id: String) -> String {
            let key = qualified(id)
            graph.addNode(id: key, label: id)
            if let scope = stack.last, let position = graph.subgraphs.firstIndex(where: { $0.id == scope }),
               !graph.subgraphs[position].members.contains(key) {
                graph.subgraphs[position].members.append(key)
            }
            return key
        }

        /// `[*]` is a start dot when it is a source and an end dot when it is a target.
        func endpoint(_ text: String, isSource: Bool) -> String {
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            if trimmed == "[*]" {
                let scope = scopePrefix()
                if isSource {
                    let key = "\(scope)[start]"
                    if graph.index(of: key) == nil {
                        startCount += 1
                        let node = graph.addNode(id: key, label: "", shape: .startDot)
                        if let scope = stack.last, let position = graph.subgraphs.firstIndex(where: { $0.id == scope }) {
                            graph.subgraphs[position].members.append(key)
                        }
                        _ = node
                    }
                    return key
                } else {
                    let key = "\(scope)[end]"
                    if graph.index(of: key) == nil {
                        endCount += 1
                        graph.addNode(id: key, label: "", shape: .endDot)
                        if let scope = stack.last, let position = graph.subgraphs.firstIndex(where: { $0.id == scope }) {
                            graph.subgraphs[position].members.append(key)
                        }
                    }
                    return key
                }
            }
            return register(trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "\"")))
        }

        for (offset, raw) in lines.enumerated() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("%%") { continue }
            if offset == 0, line.lowercased().hasPrefix("statediagram") { continue }
            if line.lowercased().hasPrefix("direction ") {
                if stack.isEmpty { graph.direction = GraphLayout.Direction(String(line.dropFirst(10)).trimmingCharacters(in: .whitespaces)) }
                continue
            }
            if line == "}" {
                _ = stack.popLast()
                continue
            }
            if line.hasPrefix("note ") || line == "end note" || line.hasPrefix("classDef") || line.hasPrefix("class ") || line.hasPrefix("style ") || line.hasPrefix("--") {
                continue
            }

            // state "Description" as id
            if let match = line.prefixMatch(of: /^state\s+"([^"]+)"\s+as\s+(\S+)\s*$/) {
                let key = register(String(match.2))
                graph.nodes[graph.index(of: key) ?? 0].label = String(match.1)
                continue
            }
            // state id <<choice>> / <<fork>> / <<join>>
            if let match = line.prefixMatch(of: /^state\s+(\S+)\s+<<(\w+)>>\s*$/) {
                let key = register(String(match.1))
                let kind = String(match.2).lowercased()
                if let index = graph.index(of: key) {
                    graph.nodes[index].shape = kind == "choice" ? .diamond : .bar
                    if kind == "choice" { graph.nodes[index].label = "" }
                }
                continue
            }
            // state Composite { … }
            if let match = line.prefixMatch(of: /^state\s+(?:"([^"]+)"\s+as\s+)?(\S+)\s*\{\s*$/) {
                let id = String(match.2)
                let key = qualified(id)
                graph.subgraphs.append(FlowGraph.Subgraph(id: key, title: match.1.map(String.init) ?? id, parent: stack.last))
                if let scope = stack.last, let position = graph.subgraphs.firstIndex(where: { $0.id == scope }) {
                    // The composite is a box, not a member node.
                    _ = position
                }
                stack.append(key)
                continue
            }
            if line.hasPrefix("state ") {
                _ = register(String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces))
                continue
            }

            // a --> b : label
            if let arrow = line.range(of: "-->") {
                let left = String(line[..<arrow.lowerBound])
                var right = String(line[arrow.upperBound...])
                var label: String?
                if let colon = right.firstIndex(of: ":") {
                    label = String(right[right.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                    right = String(right[..<colon])
                }
                let from = endpoint(left, isSource: true)
                let to = endpoint(right, isSource: false)
                graph.edges.append(FlowGraph.Edge(from: from, to: to, label: label?.isEmpty == true ? nil : label))
                continue
            }

            // id : description
            if let colon = line.firstIndex(of: ":") {
                let id = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
                let description = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                let key = register(id)
                if let index = graph.index(of: key) {
                    let current = graph.nodes[index].label
                    graph.nodes[index].label = current == id ? description : current + "\n" + description
                }
                continue
            }
            _ = register(line)
        }
        for index in graph.nodes.indices where graph.nodes[index].shape == .rectangle {
            graph.nodes[index].shape = .rounded
            if graph.nodes[index].label.contains(".") && graph.nodes[index].label == graph.nodes[index].id {
                graph.nodes[index].label = String(graph.nodes[index].label.split(separator: ".").last ?? "")
            }
        }
        return graph
    }
}
