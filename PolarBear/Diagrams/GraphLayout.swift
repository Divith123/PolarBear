//
//  GraphLayout.swift
//  PolarBear
//

import CoreGraphics
import Foundation

/// Lays out a directed graph in layers (the arrangement flowcharts, state, class and ER
/// diagrams use): nodes are assigned to ranks, ordered inside each rank to reduce crossings,
/// and spread across the rank; edges that skip ranks are routed through the gaps.
nonisolated enum GraphLayout {
    enum Direction: Sendable {
        case topDown, bottomUp, leftRight, rightLeft

        init(_ text: String) {
            switch text.uppercased() {
            case "LR": self = .leftRight
            case "RL": self = .rightLeft
            case "BT": self = .bottomUp
            default: self = .topDown
            }
        }
    }

    enum Outline: Sendable {
        case rectangle, ellipse, diamond
    }

    struct Node: Sendable {
        var size: CGSize
        var outline = Outline.rectangle
    }

    struct Edge: Sendable {
        var from: Int
        var to: Int
        /// The room a label on this edge needs.
        var labelSize: CGSize?
    }

    struct Route: Sendable {
        /// From the border of the source to the border of the target.
        var points: [CGPoint]
        var labelPosition: CGPoint?
    }

    struct Result: Sendable {
        var centers: [CGPoint]
        var routes: [Route]
        var size: CGSize
    }

    // MARK: Entry point

    static func layout(
        nodes: [Node],
        edges: [Edge],
        direction: Direction = .topDown,
        nodeGap: Double = 40,
        rankGap: Double = 64
    ) -> Result {
        guard !nodes.isEmpty else { return Result(centers: [], routes: [], size: .zero) }

        let horizontal = direction == .leftRight || direction == .rightLeft
        // Work as if the graph runs top to bottom; sideways graphs swap width and height.
        let workNodes = nodes.map { node -> Node in
            var copy = node
            if horizontal { copy.size = CGSize(width: node.size.height, height: node.size.width) }
            return copy
        }
        let workEdges = edges.map { edge -> Edge in
            var copy = edge
            if horizontal, let label = edge.labelSize { copy.labelSize = CGSize(width: label.height, height: label.width) }
            return copy
        }

        var layered = Layered(nodes: workNodes, edges: workEdges, nodeGap: nodeGap, rankGap: rankGap)
        layered.run()

        // Orient the result.
        var centers = layered.centers
        var routes = layered.routes
        var size = layered.size
        func transform(_ point: CGPoint) -> CGPoint {
            var result = horizontal ? CGPoint(x: point.y, y: point.x) : point
            let extent = horizontal ? CGSize(width: size.height, height: size.width) : size
            if direction == .bottomUp { result.y = extent.height - result.y }
            if direction == .rightLeft { result.x = extent.width - result.x }
            return result
        }
        centers = centers.map(transform)
        routes = routes.map { Route(points: $0.points.map(transform), labelPosition: $0.labelPosition.map(transform)) }
        if horizontal { size = CGSize(width: size.height, height: size.width) }

        // Trim each route to the borders of its end nodes.
        for index in routes.indices where routes[index].points.count >= 2 {
            let edge = edges[index]
            guard edge.from != edge.to else { continue }
            var points = routes[index].points
            points[0] = border(of: nodes[edge.from], center: centers[edge.from], toward: points[1])
            points[points.count - 1] = border(of: nodes[edge.to], center: centers[edge.to], toward: points[points.count - 2])
            routes[index].points = points
        }
        return Result(centers: centers, routes: routes, size: size)
    }

    /// Where the line from the centre of `node` toward `point` leaves the node.
    static func border(of node: Node, center: CGPoint, toward point: CGPoint) -> CGPoint {
        let dx = point.x - center.x, dy = point.y - center.y
        guard dx != 0 || dy != 0 else { return center }
        let halfWidth = node.size.width / 2, halfHeight = node.size.height / 2
        guard halfWidth > 0, halfHeight > 0 else { return center }
        let scale: Double
        switch node.outline {
        case .rectangle:
            scale = min(abs(dx) > 0 ? halfWidth / abs(dx) : .infinity, abs(dy) > 0 ? halfHeight / abs(dy) : .infinity)
        case .ellipse:
            scale = 1 / sqrt((dx * dx) / (halfWidth * halfWidth) + (dy * dy) / (halfHeight * halfHeight))
        case .diamond:
            scale = 1 / (abs(dx) / halfWidth + abs(dy) / halfHeight)
        }
        return CGPoint(x: center.x + dx * scale, y: center.y + dy * scale)
    }

    // MARK: SVG path

    /// A smooth path through `points` (straight for two points).
    static func path(_ points: [CGPoint]) -> String {
        guard let first = points.first else { return "" }
        var d = "M\(DiagramText.number(first.x)),\(DiagramText.number(first.y))"
        if points.count == 2 {
            d += " L\(DiagramText.number(points[1].x)),\(DiagramText.number(points[1].y))"
            return d
        }
        // Catmull-Rom spline converted to cubic Béziers.
        for index in 0..<(points.count - 1) {
            let p0 = points[max(index - 1, 0)], p1 = points[index], p2 = points[index + 1]
            let p3 = points[min(index + 2, points.count - 1)]
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            d += " C\(DiagramText.number(c1.x)),\(DiagramText.number(c1.y)) \(DiagramText.number(c2.x)),\(DiagramText.number(c2.y)) \(DiagramText.number(p2.x)),\(DiagramText.number(p2.y))"
        }
        return d
    }
}
