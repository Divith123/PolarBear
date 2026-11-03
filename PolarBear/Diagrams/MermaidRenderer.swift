//
//  MermaidRenderer.swift
//  PolarBear
//

import CoreGraphics
import Foundation

/// Draws Mermaid diagrams (a ```` ```mermaid ```` block) as SVG, natively, with no script and no
/// network. Supported: flowcharts, sequence, class, state and entity-relationship diagrams, pie
/// charts, Gantt charts and git graphs.
nonisolated enum MermaidRenderer {
    /// A diagram with more nodes than this is shown as code; laying it out would take too long.
    private static let maximumNodes = 300

    /// The SVG for `source`, or `nil` for a diagram type that is not supported (the block is then
    /// shown as code).
    static func svg(_ source: String, prefix: String) -> String? {
        var lines = source.replacing("\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        // Optional YAML header (`---` … `---`) with a title or configuration.
        var title: String?
        if lines.first?.trimmingCharacters(in: .whitespaces) == "---", let end = lines.dropFirst().firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) {
            for line in lines[1..<end] {
                if let match = line.prefixMatch(of: /^\s*title:\s*(.+)$/) { title = String(match.1).trimmingCharacters(in: CharacterSet(charactersIn: "\"' ")) }
            }
            lines = Array(lines[(end + 1)...])
        }
        // `%%{init: …}%%` directives and comments.
        lines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("%%") }
        while let first = lines.first, first.trimmingCharacters(in: .whitespaces).isEmpty { lines.removeFirst() }
        guard let header = lines.first?.trimmingCharacters(in: .whitespaces).lowercased() else { return nil }

        let drawing: String?
        if header.hasPrefix("graph") || header.hasPrefix("flowchart") {
            let graph = FlowchartParser.parse(lines)
            drawing = graph.nodes.count > maximumNodes ? nil : FlowchartRenderer.svg(graph, prefix: prefix)
        } else if header.hasPrefix("sequencediagram") {
            drawing = SequenceDiagram.parse(lines).svg(prefix: prefix)
        } else if header.hasPrefix("classdiagram") {
            drawing = ClassDiagram.parse(lines).svg(prefix: prefix)
        } else if header.hasPrefix("erdiagram") {
            drawing = ERDiagram.parse(lines).svg()
        } else if header.hasPrefix("gantt") {
            drawing = GanttChart.parse(lines).svg()
        } else if header.hasPrefix("gitgraph") {
            drawing = GitGraph.parse(lines).svg()
        } else if header.hasPrefix("pie") {
            drawing = PieChart.parse(lines).svg()
        } else if header.hasPrefix("statediagram") {
            let graph = StateDiagramParser.parse(lines)
            drawing = graph.nodes.count > maximumNodes ? nil : FlowchartRenderer.svg(graph, prefix: prefix)
        } else {
            drawing = nil
        }
        guard let drawing, !drawing.isEmpty else { return nil }
        if let title {
            return "<div class=\"diagram-title\">\(DiagramText.escape(title))</div>\n" + drawing
        }
        return drawing
    }
}
