//
//  ERDiagram.swift
//  PolarBear
//

import CoreGraphics
import Foundation

/// A Mermaid `erDiagram`: entities with attributes, and relationships with cardinalities.
nonisolated struct ERDiagram {
    struct Attribute {
        var type: String
        var name: String
        var keys: String
        var comment: String
    }

    struct Entity {
        var name: String
        var attributes: [Attribute] = []
    }

    enum Cardinality { case one, zeroOrOne, oneOrMany, zeroOrMany }

    struct Relationship {
        var from: String
        var to: String
        var fromCardinality: Cardinality
        var toCardinality: Cardinality
        var isIdentifying: Bool
        var label: String
    }

    var entities: [Entity] = []
    var relationships: [Relationship] = []
    var direction = GraphLayout.Direction.topDown

    // MARK: Parsing

    static func parse(_ lines: [String]) -> ERDiagram {
        var diagram = ERDiagram()

        func index(of name: String) -> Int {
            if let found = diagram.entities.firstIndex(where: { $0.name == name }) { return found }
            diagram.entities.append(Entity(name: name))
            return diagram.entities.count - 1
        }
        func cardinality(_ symbol: String) -> Cardinality {
            switch symbol {
            case "|o", "o|": .zeroOrOne
            case "}|", "|{": .oneOrMany
            case "}o", "o{": .zeroOrMany
            default: .one
            }
        }

        var body: Int?
        for (offset, raw) in lines.enumerated() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("%%") || (offset == 0 && line.lowercased().hasPrefix("erdiagram")) { continue }
            if let current = body {
                if line == "}" {
                    body = nil
                } else if let match = line.prefixMatch(of: /^(\S+)\s+(\S+)(?:\s+((?:PK|FK|UK)(?:\s*,\s*(?:PK|FK|UK))*))?(?:\s+"([^"]*)")?\s*$/) {
                    diagram.entities[current].attributes.append(Attribute(
                        type: String(match.1), name: String(match.2),
                        keys: match.3.map { String($0).replacing(/\s+/, with: "") } ?? "", comment: match.4.map(String.init) ?? ""
                    ))
                }
                continue
            }
            if line.lowercased().hasPrefix("direction ") {
                diagram.direction = GraphLayout.Direction(String(line.dropFirst(10)).trimmingCharacters(in: .whitespaces))
                continue
            }
            if let match = line.prefixMatch(of: /^(\S+?)(?:\["[^"]*"\])?\s*\{\s*$/) {
                body = index(of: String(match.1))
                continue
            }
            if let match = line.prefixMatch(of: /^(\S+)\s+(\|\||\|o|\}\||\}o)(--|\.\.)(\|\||o\||\|\{|o\{)\s+(\S+)\s*(?::\s*(.*))?$/) {
                _ = index(of: String(match.1))
                _ = index(of: String(match.5))
                diagram.relationships.append(Relationship(
                    from: String(match.1), to: String(match.5),
                    fromCardinality: cardinality(String(match.2)), toCardinality: cardinality(String(match.4)),
                    isIdentifying: match.3 == "--",
                    label: (match.6.map { String($0) } ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "\" "))
                ))
                continue
            }
            if !line.contains(" ") { _ = index(of: line) }
        }
        return diagram
    }

    // MARK: Drawing

    private struct Metrics {
        var width: Double
        var height: Double
        var columns: [Double]
    }

    func svg() -> String {
        guard !entities.isEmpty else { return "" }
        func n(_ value: Double) -> String { DiagramText.number(value) }
        let rowHeight = 24.0, headerHeight = 34.0

        let metrics = entities.map { entity -> Metrics in
            var columns = [0.0, 0.0, 0.0, 0.0]
            for attribute in entity.attributes {
                columns[0] = max(columns[0], DiagramText.width(attribute.type, size: 13))
                columns[1] = max(columns[1], DiagramText.width(attribute.name, size: 13))
                columns[2] = max(columns[2], DiagramText.width(attribute.keys, size: 12, bold: true))
                columns[3] = max(columns[3], DiagramText.width(attribute.comment, size: 12))
            }
            let padded = columns.map { $0 > 0 ? $0 + 20 : 0 }
            let title = DiagramText.width(entity.name, size: 14, bold: true) + 36
            let content = padded.reduce(0, +)
            let width = max(title, content, 90)
            var widened = padded
            if content < width, let lastIndex = widened.lastIndex(where: { $0 > 0 }) { widened[lastIndex] += width - content }
            return Metrics(width: width, height: headerHeight + Double(max(entity.attributes.count, 0)) * rowHeight + (entity.attributes.isEmpty ? 6 : 4), columns: widened)
        }

        func position(of name: String) -> Int { entities.firstIndex { $0.name == name } ?? 0 }
        let edges = relationships.map { relationship -> GraphLayout.Edge in
            let label = relationship.label.isEmpty ? nil : DiagramText.size(of: [relationship.label], fontSize: 12)
            return GraphLayout.Edge(from: position(of: relationship.from), to: position(of: relationship.to), labelSize: label.map { CGSize(width: $0.width + 12, height: $0.height + 6) })
        }
        let layout = GraphLayout.layout(
            nodes: metrics.map { GraphLayout.Node(size: CGSize(width: $0.width, height: $0.height)) },
            edges: edges, direction: direction, nodeGap: 56, rankGap: 90
        )

        var body = ""
        for (index, relationship) in relationships.enumerated() {
            let route = layout.routes[index]
            guard route.points.count >= 2 else { continue }
            var attributes = "fill=\"none\" stroke=\"\(DiagramTheme.line)\" stroke-width=\"1.5\""
            if !relationship.isIdentifying { attributes += " stroke-dasharray=\"6 4\"" }
            body += "<path d=\"\(GraphLayout.path(route.points))\" \(attributes)/>"
            body += cardinalitySymbol(relationship.fromCardinality, at: route.points[0], toward: route.points[1])
            body += cardinalitySymbol(relationship.toCardinality, at: route.points[route.points.count - 1], toward: route.points[route.points.count - 2])
            if !relationship.label.isEmpty, let at = route.labelPosition {
                let width = DiagramText.width(relationship.label, size: 12) + 12
                body += "<rect x=\"\(n(at.x - width / 2))\" y=\"\(n(at.y - 10))\" width=\"\(n(width))\" height=\"20\" rx=\"3\" fill=\"#ffffff\" fill-opacity=\"0.94\"/>"
                body += DiagramText.centred([relationship.label], at: at, fontSize: 12, fill: DiagramTheme.mutedText)
            }
        }

        for (index, entity) in entities.enumerated() {
            let size = metrics[index]
            let center = layout.centers[index]
            let x = center.x - size.width / 2, y = center.y - size.height / 2
            body += "<rect x=\"\(n(x))\" y=\"\(n(y))\" width=\"\(n(size.width))\" height=\"\(n(size.height))\" fill=\"#ffffff\" stroke=\"\(DiagramTheme.nodeStroke)\" stroke-width=\"1.5\"/>"
            body += "<rect x=\"\(n(x))\" y=\"\(n(y))\" width=\"\(n(size.width))\" height=\"\(n(headerHeight))\" fill=\"\(DiagramTheme.nodeFill)\" stroke=\"\(DiagramTheme.nodeStroke)\" stroke-width=\"1.5\"/>"
            body += DiagramText.centred([entity.name], at: CGPoint(x: center.x, y: y + headerHeight / 2), fontSize: 14, bold: true)
            for (row, attribute) in entity.attributes.enumerated() {
                let top = y + headerHeight + Double(row) * rowHeight
                if row % 2 == 1 {
                    body += "<rect x=\"\(n(x + 0.75))\" y=\"\(n(top))\" width=\"\(n(size.width - 1.5))\" height=\"\(n(rowHeight))\" fill=\"#f6f7ff\"/>"
                }
                var cursor = x
                let cells = [attribute.type, attribute.name, attribute.keys, attribute.comment]
                for (column, text) in cells.enumerated() where size.columns[column] > 0 {
                    if !text.isEmpty {
                        body += DiagramText.centred([text], at: CGPoint(x: cursor + 10, y: top + rowHeight / 2), fontSize: column >= 2 ? 12 : 13, bold: column == 2, fill: column == 3 ? DiagramTheme.mutedText : DiagramTheme.text, anchor: "start")
                    }
                    cursor += size.columns[column]
                }
            }
        }
        return "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 \(n(layout.size.width)) \(n(layout.size.height))\" width=\"\(n(layout.size.width))\" height=\"\(n(layout.size.height))\" font-family=\"-apple-system, 'SF Pro Text', Helvetica, Arial, sans-serif\">\n\(body)</svg>"
    }

    /// Crow's-foot notation at the end of a line: `point` is where the line meets the entity.
    private func cardinalitySymbol(_ cardinality: Cardinality, at point: CGPoint, toward neighbour: CGPoint) -> String {
        func n(_ value: Double) -> String { DiagramText.number(value) }
        let dx = neighbour.x - point.x, dy = neighbour.y - point.y
        let length = max(sqrt(dx * dx + dy * dy), 1)
        let direction = CGPoint(x: dx / length, y: dy / length)
        let normal = CGPoint(x: -direction.y, y: direction.x)
        func at(_ distance: Double, _ side: Double = 0) -> CGPoint {
            CGPoint(x: point.x + direction.x * distance + normal.x * side, y: point.y + direction.y * distance + normal.y * side)
        }
        func tick(_ distance: Double) -> String {
            let a = at(distance, -7), b = at(distance, 7)
            return "<line x1=\"\(n(a.x))\" y1=\"\(n(a.y))\" x2=\"\(n(b.x))\" y2=\"\(n(b.y))\" stroke=\"\(DiagramTheme.line)\" stroke-width=\"1.5\"/>"
        }
        func ring(_ distance: Double) -> String {
            let c = at(distance)
            return "<circle cx=\"\(n(c.x))\" cy=\"\(n(c.y))\" r=\"5\" fill=\"#ffffff\" stroke=\"\(DiagramTheme.line)\" stroke-width=\"1.5\"/>"
        }
        func foot() -> String {
            let tip = at(15)
            var path = ""
            for side in [-8.0, 0, 8.0] {
                let end = at(0, side)
                path += "M\(n(tip.x)),\(n(tip.y)) L\(n(end.x)),\(n(end.y)) "
            }
            return "<path d=\"\(path)\" fill=\"none\" stroke=\"\(DiagramTheme.line)\" stroke-width=\"1.5\"/>"
        }
        switch cardinality {
        case .one: return tick(11) + tick(16)
        case .zeroOrOne: return tick(11) + ring(21)
        case .oneOrMany: return foot() + tick(19)
        case .zeroOrMany: return foot() + ring(25)
        }
    }
}
