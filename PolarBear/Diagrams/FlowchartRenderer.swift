//
//  FlowchartRenderer.swift
//  PolarBear
//

import CoreGraphics
import Foundation

/// Draws a `FlowGraph` (a flowchart or a state diagram) as SVG.
nonisolated enum FlowchartRenderer {
    private struct Metrics {
        var size: CGSize
        var outline: GraphLayout.Outline
    }

    static func svg(_ graph: FlowGraph, prefix: String) -> String {
        guard !graph.nodes.isEmpty else { return "" }

        let metrics = graph.nodes.map(self.metrics)
        let layoutNodes = metrics.map { GraphLayout.Node(size: $0.size, outline: $0.outline) }
        let layoutEdges: [GraphLayout.Edge] = graph.edges.map { edge in
            let label = edge.label.map { DiagramText.size(of: DiagramText.lines($0), fontSize: 13) }
            return GraphLayout.Edge(
                from: graph.index(of: edge.from) ?? 0,
                to: graph.index(of: edge.to) ?? 0,
                labelSize: label.map { CGSize(width: $0.width + 14, height: $0.height + 6) }
            )
        }
        let layout = GraphLayout.layout(nodes: layoutNodes, edges: layoutEdges, direction: graph.direction)

        var body = ""
        let groups = subgraphs(graph, layout: layout, metrics: metrics)
        body += groups.markup

        for (index, edge) in graph.edges.enumerated() where edge.style != .invisible {
            body += self.edge(edge, route: layout.routes[index], layoutNode: layoutNodes[layoutEdges[index].from], center: layout.centers[layoutEdges[index].from], prefix: prefix)
        }
        for (index, node) in graph.nodes.enumerated() {
            body += self.node(node, center: layout.centers[index], size: metrics[index].size, classes: graph.classes)
        }
        for (index, edge) in graph.edges.enumerated() where edge.style != .invisible {
            if let label = edge.label, let position = layout.routes[index].labelPosition ?? labelFallback(layout.routes[index]) {
                body += edgeLabel(label, at: position)
            }
        }

        var bounds = CGRect(origin: .zero, size: layout.size)
        if let extra = groups.bounds { bounds = bounds.union(extra.insetBy(dx: -8, dy: -8)) }
        let width = bounds.width, height = bounds.height
        return """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="\(DiagramText.number(bounds.minX)) \(DiagramText.number(bounds.minY)) \(DiagramText.number(width)) \(DiagramText.number(height))" width="\(DiagramText.number(width))" height="\(DiagramText.number(height))" font-family="-apple-system, 'SF Pro Text', Helvetica, Arial, sans-serif">
        \(SVGMarkers.definitions(prefix: prefix))
        \(body)</svg>
        """
    }

    // MARK: Sizes

    private static func metrics(for node: FlowGraph.Node) -> Metrics {
        let lines = DiagramText.lines(node.label)
        let text = DiagramText.size(of: lines)
        let paddedWidth = text.width + 36, paddedHeight = max(text.height + 20, 38)
        switch node.shape {
        case .circle, .doubleCircle:
            let diameter = max(text.width + 28, text.height + 28, 44) + (node.shape == .doubleCircle ? 10 : 0)
            return Metrics(size: CGSize(width: diameter, height: diameter), outline: .ellipse)
        case .diamond:
            return Metrics(size: CGSize(width: text.width * 1.5 + 36, height: max(text.height * 1.6 + 30, 56)), outline: .diamond)
        case .hexagon:
            return Metrics(size: CGSize(width: paddedWidth + paddedHeight / 2, height: paddedHeight), outline: .rectangle)
        case .cylinder:
            return Metrics(size: CGSize(width: paddedWidth, height: paddedHeight + 18), outline: .rectangle)
        case .startDot:
            return Metrics(size: CGSize(width: 20, height: 20), outline: .ellipse)
        case .endDot:
            return Metrics(size: CGSize(width: 26, height: 26), outline: .ellipse)
        case .bar:
            return Metrics(size: CGSize(width: 70, height: 8), outline: .rectangle)
        case .parallelogram, .parallelogramAlt, .trapezoid, .trapezoidAlt:
            return Metrics(size: CGSize(width: paddedWidth + 26, height: paddedHeight), outline: .rectangle)
        case .stadium:
            return Metrics(size: CGSize(width: paddedWidth + 14, height: paddedHeight), outline: .rectangle)
        default:
            return Metrics(size: CGSize(width: max(paddedWidth, 56), height: paddedHeight), outline: .rectangle)
        }
    }

    // MARK: Nodes

    private static func node(_ node: FlowGraph.Node, center: CGPoint, size: CGSize, classes: [String: [String: String]]) -> String {
        var properties = node.className.flatMap { classes[$0] } ?? [:]
        properties.merge(node.style) { $1 }
        let fill = properties["fill"] ?? DiagramTheme.nodeFill
        let stroke = properties["stroke"] ?? DiagramTheme.nodeStroke
        let strokeWidth = properties["stroke-width"] ?? "1.5"
        let dash = properties["stroke-dasharray"].map { " stroke-dasharray=\"\(DiagramText.escape($0))\"" } ?? ""
        let textColor = properties["color"] ?? DiagramTheme.text
        let appearance = "fill=\"\(DiagramText.escape(fill))\" stroke=\"\(DiagramText.escape(stroke))\" stroke-width=\"\(DiagramText.escape(strokeWidth.replacing("px", with: "")))\"\(dash)"

        let x = center.x - size.width / 2, y = center.y - size.height / 2
        let w = size.width, h = size.height
        func n(_ value: Double) -> String { DiagramText.number(value) }
        var shape = ""
        switch node.shape {
        case .rectangle:
            shape = "<rect x=\"\(n(x))\" y=\"\(n(y))\" width=\"\(n(w))\" height=\"\(n(h))\" rx=\"3\" \(appearance)/>"
        case .rounded:
            shape = "<rect x=\"\(n(x))\" y=\"\(n(y))\" width=\"\(n(w))\" height=\"\(n(h))\" rx=\"10\" \(appearance)/>"
        case .stadium:
            shape = "<rect x=\"\(n(x))\" y=\"\(n(y))\" width=\"\(n(w))\" height=\"\(n(h))\" rx=\"\(n(h / 2))\" \(appearance)/>"
        case .subroutine:
            shape = "<rect x=\"\(n(x))\" y=\"\(n(y))\" width=\"\(n(w))\" height=\"\(n(h))\" \(appearance)/><path d=\"M\(n(x + 8)),\(n(y)) V\(n(y + h)) M\(n(x + w - 8)),\(n(y)) V\(n(y + h))\" stroke=\"\(DiagramText.escape(stroke))\" stroke-width=\"1.5\" fill=\"none\"/>"
        case .cylinder:
            let ry = 9.0
            shape = "<path d=\"M\(n(x)),\(n(y + ry)) A\(n(w / 2)),\(n(ry)) 0 0 1 \(n(x + w)),\(n(y + ry)) V\(n(y + h - ry)) A\(n(w / 2)),\(n(ry)) 0 0 1 \(n(x)),\(n(y + h - ry)) Z\" \(appearance)/><path d=\"M\(n(x)),\(n(y + ry)) A\(n(w / 2)),\(n(ry)) 0 0 0 \(n(x + w)),\(n(y + ry))\" fill=\"none\" stroke=\"\(DiagramText.escape(stroke))\" stroke-width=\"1.5\"/>"
        case .circle:
            shape = "<ellipse cx=\"\(n(center.x))\" cy=\"\(n(center.y))\" rx=\"\(n(w / 2))\" ry=\"\(n(h / 2))\" \(appearance)/>"
        case .doubleCircle:
            shape = "<ellipse cx=\"\(n(center.x))\" cy=\"\(n(center.y))\" rx=\"\(n(w / 2))\" ry=\"\(n(h / 2))\" \(appearance)/><ellipse cx=\"\(n(center.x))\" cy=\"\(n(center.y))\" rx=\"\(n(w / 2 - 5))\" ry=\"\(n(h / 2 - 5))\" fill=\"none\" stroke=\"\(DiagramText.escape(stroke))\" stroke-width=\"1.5\"/>"
        case .diamond:
            shape = "<polygon points=\"\(n(center.x)),\(n(y)) \(n(x + w)),\(n(center.y)) \(n(center.x)),\(n(y + h)) \(n(x)),\(n(center.y))\" \(appearance)/>"
        case .hexagon:
            let inset = h / 4
            shape = "<polygon points=\"\(n(x + inset)),\(n(y)) \(n(x + w - inset)),\(n(y)) \(n(x + w)),\(n(center.y)) \(n(x + w - inset)),\(n(y + h)) \(n(x + inset)),\(n(y + h)) \(n(x)),\(n(center.y))\" \(appearance)/>"
        case .parallelogram:
            shape = "<polygon points=\"\(n(x + 14)),\(n(y)) \(n(x + w)),\(n(y)) \(n(x + w - 14)),\(n(y + h)) \(n(x)),\(n(y + h))\" \(appearance)/>"
        case .parallelogramAlt:
            shape = "<polygon points=\"\(n(x)),\(n(y)) \(n(x + w - 14)),\(n(y)) \(n(x + w)),\(n(y + h)) \(n(x + 14)),\(n(y + h))\" \(appearance)/>"
        case .trapezoid:
            shape = "<polygon points=\"\(n(x + 14)),\(n(y)) \(n(x + w - 14)),\(n(y)) \(n(x + w)),\(n(y + h)) \(n(x)),\(n(y + h))\" \(appearance)/>"
        case .trapezoidAlt:
            shape = "<polygon points=\"\(n(x)),\(n(y)) \(n(x + w)),\(n(y)) \(n(x + w - 14)),\(n(y + h)) \(n(x + 14)),\(n(y + h))\" \(appearance)/>"
        case .asymmetric:
            shape = "<polygon points=\"\(n(x)),\(n(y)) \(n(x + w)),\(n(y)) \(n(x + w)),\(n(y + h)) \(n(x)),\(n(y + h)) \(n(x + 14)),\(n(center.y))\" \(appearance)/>"
        case .startDot:
            return "<circle cx=\"\(n(center.x))\" cy=\"\(n(center.y))\" r=\"9\" fill=\"\(DiagramTheme.line)\"/>"
        case .endDot:
            return "<circle cx=\"\(n(center.x))\" cy=\"\(n(center.y))\" r=\"12\" fill=\"#ffffff\" stroke=\"\(DiagramTheme.line)\" stroke-width=\"2\"/><circle cx=\"\(n(center.x))\" cy=\"\(n(center.y))\" r=\"7\" fill=\"\(DiagramTheme.line)\"/>"
        case .bar:
            return "<rect x=\"\(n(x))\" y=\"\(n(y))\" width=\"\(n(w))\" height=\"\(n(h))\" rx=\"2\" fill=\"\(DiagramTheme.line)\"/>"
        }
        let lines = DiagramText.lines(node.label)
        return shape + DiagramText.centred(lines, at: center, fill: DiagramText.escape(textColor))
    }

    // MARK: Edges

    private static func edge(_ edge: FlowGraph.Edge, route: GraphLayout.Route, layoutNode: GraphLayout.Node, center: CGPoint, prefix: String) -> String {
        var points = route.points
        guard points.count >= 2 else { return "" }
        let isLoop = points.count == 2 && points[0] == points[1]
        var d: String
        if isLoop {
            let right = center.x + layoutNode.size.width / 2
            d = "M\(DiagramText.number(right)),\(DiagramText.number(center.y - 8)) C\(DiagramText.number(right + 34)),\(DiagramText.number(center.y - 34)) \(DiagramText.number(right + 34)),\(DiagramText.number(center.y + 34)) \(DiagramText.number(right)),\(DiagramText.number(center.y + 8))"
        } else {
            // Pull the line slightly away from the arrow end so the head sits on the border.
            if points.count >= 2 { points = points.map { $0 } }
            d = GraphLayout.path(points)
        }
        let width: String
        var dash = ""
        switch edge.style {
        case .thick: width = "3"
        case .dotted:
            width = "1.6"
            dash = " stroke-dasharray=\"2 5\" stroke-linecap=\"round\""
        default: width = "1.6"
        }
        func marker(_ ending: FlowGraph.Ending) -> String? {
            switch ending {
            case .none: nil
            case .arrow: "\(prefix)-arrow"
            case .circle: "\(prefix)-circle"
            case .cross: "\(prefix)-cross"
            }
        }
        var attributes = "fill=\"none\" stroke=\"\(DiagramTheme.line)\" stroke-width=\"\(width)\"\(dash)"
        if let head = marker(edge.head) { attributes += " marker-end=\"url(#\(head))\"" }
        if let tail = marker(edge.tail) { attributes += " marker-start=\"url(#\(tail))\"" }
        return "<path d=\"\(d)\" \(attributes)/>"
    }

    private static func labelFallback(_ route: GraphLayout.Route) -> CGPoint? {
        guard route.points.count >= 2, let first = route.points.first, let last = route.points.last else { return nil }
        if route.points.count == 2, first == last { return CGPoint(x: first.x + 52, y: first.y - 18) }
        let middle = route.points[route.points.count / 2]
        return route.points.count % 2 == 0
            ? CGPoint(x: (route.points[route.points.count / 2 - 1].x + middle.x) / 2, y: (route.points[route.points.count / 2 - 1].y + middle.y) / 2)
            : middle
    }

    private static func edgeLabel(_ label: String, at position: CGPoint) -> String {
        let lines = DiagramText.lines(label)
        let size = DiagramText.size(of: lines, fontSize: 13)
        let w = size.width + 12, h = size.height + 4
        return "<rect x=\"\(DiagramText.number(position.x - w / 2))\" y=\"\(DiagramText.number(position.y - h / 2))\" width=\"\(DiagramText.number(w))\" height=\"\(DiagramText.number(h))\" rx=\"3\" fill=\"#ffffff\" fill-opacity=\"0.92\"/>"
            + DiagramText.centred(lines, at: position, fontSize: 13, fill: DiagramTheme.mutedText)
    }

    // MARK: Subgraphs

    private static func subgraphs(_ graph: FlowGraph, layout: GraphLayout.Result, metrics: [Metrics]) -> (markup: String, bounds: CGRect?) {
        guard !graph.subgraphs.isEmpty else { return ("", nil) }
        var rects: [String: CGRect] = [:]

        func memberBox(_ id: String) -> CGRect? {
            guard let subgraph = graph.subgraphs.first(where: { $0.id == id }) else { return nil }
            var box: CGRect?
            for member in subgraph.members {
                guard let index = graph.index(of: member) else { continue }
                let size = metrics[index].size, center = layout.centers[index]
                let rect = CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
                box = box.map { $0.union(rect) } ?? rect
            }
            for child in graph.subgraphs where child.parent == id {
                if let childBox = memberBox(child.id) {
                    let padded = childBox.insetBy(dx: -18, dy: -18).offsetBy(dx: 0, dy: -10)
                    box = box.map { $0.union(padded) } ?? padded
                }
            }
            return box
        }

        func depth(_ subgraph: FlowGraph.Subgraph) -> Int {
            var level = 0
            var parent = subgraph.parent
            while let id = parent, let next = graph.subgraphs.first(where: { $0.id == id }) {
                level += 1
                parent = next.parent
            }
            return level
        }

        var markup = ""
        var union: CGRect?
        for subgraph in graph.subgraphs.sorted(by: { depth($0) < depth($1) }) {
            guard let box = memberBox(subgraph.id) else { continue }
            let padded = box.insetBy(dx: -18, dy: -18).offsetBy(dx: 0, dy: -12).applying(.identity)
            let rect = CGRect(x: padded.minX, y: padded.minY, width: padded.width, height: padded.height + 12)
            rects[subgraph.id] = rect
            let drawn = CGRect(x: rect.minX, y: rect.minY - 12, width: rect.width, height: rect.height + 12)
            union = union.map { $0.union(drawn) } ?? drawn
            markup += "<rect x=\"\(DiagramText.number(rect.minX))\" y=\"\(DiagramText.number(rect.minY - 12))\" width=\"\(DiagramText.number(rect.width))\" height=\"\(DiagramText.number(rect.height + 12))\" rx=\"8\" fill=\"\(DiagramTheme.panelFill)\" stroke=\"\(DiagramTheme.panelStroke)\" stroke-width=\"1.2\"/>"
            markup += DiagramText.centred([subgraph.title], at: CGPoint(x: rect.midX, y: rect.minY + 2), fontSize: 13, bold: true, fill: DiagramTheme.mutedText)
        }
        return (markup, union)
    }
}
