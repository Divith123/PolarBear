//
//  ClassDiagram.swift
//  PolarBear
//

import CoreGraphics
import Foundation

/// A Mermaid `classDiagram`.
nonisolated struct ClassDiagram {
    struct ClassBox {
        var name: String
        var annotation: String?
        var attributes: [String] = []
        var methods: [String] = []
    }

    enum Marker { case none, triangle, diamond, filledDiamond, arrow }

    struct Relation {
        var from: String
        var to: String
        var fromMarker: Marker
        var toMarker: Marker
        var isDashed: Bool
        var label: String?
        var fromCardinality: String?
        var toCardinality: String?
    }

    var classes: [ClassBox] = []
    var relations: [Relation] = []
    var direction = GraphLayout.Direction.topDown

    // MARK: Parsing

    private static let relationOperators: [(text: String, from: Marker, to: Marker, dashed: Bool)] = [
        ("<|--", .triangle, .none, false), ("--|>", .none, .triangle, false),
        ("<|..", .triangle, .none, true), ("..|>", .none, .triangle, true),
        ("*--", .filledDiamond, .none, false), ("--*", .none, .filledDiamond, false),
        ("o--", .diamond, .none, false), ("--o", .none, .diamond, false),
        ("<--", .arrow, .none, false), ("-->", .none, .arrow, false),
        ("<..", .arrow, .none, true), ("..>", .none, .arrow, true),
        ("--", .none, .none, false), ("..", .none, .none, true),
    ]

    static func parse(_ lines: [String]) -> ClassDiagram {
        var diagram = ClassDiagram()

        func index(of name: String) -> Int {
            let clean = name.replacing(/~([^~]*)~/, with: { "<\($0.1)>" })
            if let found = diagram.classes.firstIndex(where: { $0.name == clean }) { return found }
            diagram.classes.append(ClassBox(name: clean))
            return diagram.classes.count - 1
        }

        var currentBody: Int?
        for (offset, raw) in lines.enumerated() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("%%") || (offset == 0 && line.lowercased().hasPrefix("classdiagram")) { continue }

            if let body = currentBody {
                if line == "}" {
                    currentBody = nil
                } else if line.hasPrefix("<<"), let end = line.range(of: ">>") {
                    diagram.classes[body].annotation = String(line[line.index(line.startIndex, offsetBy: 2)..<end.lowerBound])
                } else {
                    diagram.add(member: line, to: body)
                }
                continue
            }
            if line.lowercased().hasPrefix("direction ") {
                diagram.direction = GraphLayout.Direction(String(line.dropFirst(10)).trimmingCharacters(in: .whitespaces))
                continue
            }
            if let match = line.prefixMatch(of: /^class\s+([^\s{]+)(?:\s*\["[^"]*"\])?\s*(\{)?\s*$/) {
                let box = index(of: String(match.1))
                if match.2 != nil { currentBody = box }
                continue
            }
            if let match = line.prefixMatch(of: /^<<(\w+)>>\s+(\S+)\s*$/) {
                diagram.classes[index(of: String(match.2))].annotation = String(match.1)
                continue
            }
            if line.hasPrefix("note ") || line.hasPrefix("click ") || line.hasPrefix("style ") || line.hasPrefix("cssClass") || line.hasPrefix("classDef") { continue }

            if let relation = parseRelation(line, index: index(of:)) {
                diagram.relations.append(relation)
                continue
            }
            // Name : +member
            if let colon = line.firstIndex(of: ":") {
                let name = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
                let member = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                if !name.isEmpty, !name.contains(" ") { diagram.add(member: member, to: index(of: name)) }
            }
        }
        return diagram
    }

    private mutating func add(member: String, to box: Int) {
        let text = member.replacing(/~([^~]*)~/, with: { "<\($0.1)>" })
        if text.contains("(") {
            classes[box].methods.append(text)
        } else {
            classes[box].attributes.append(text)
        }
    }

    private static func parseRelation(_ line: String, index: (String) -> Int) -> Relation? {
        guard let match = line.prefixMatch(of: /^(\S+?)\s*(?:"([^"]*)"\s*)?(<\|--|--\|>|<\|\.\.|\.\.\|>|\*--|--\*|o--|--o|<--|-->|<\.\.|\.\.>|--|\.\.)\s*(?:"([^"]*)"\s*)?(\S+?)\s*(?::\s*(.*))?$/) else {
            return nil
        }
        guard let op = relationOperators.first(where: { $0.text == String(match.3) }) else { return nil }
        let from = index(String(match.1)), to = index(String(match.5))
        _ = (from, to)
        let clean: (String) -> String = { $0.replacing(/~([^~]*)~/, with: { "<\($0.1)>" }) }
        return Relation(
            from: clean(String(match.1)), to: clean(String(match.5)),
            fromMarker: op.from, toMarker: op.to, isDashed: op.dashed,
            label: match.6.map { String($0).trimmingCharacters(in: .whitespaces) },
            fromCardinality: match.2.map(String.init), toCardinality: match.4.map(String.init)
        )
    }

    // MARK: Drawing

    private struct Layout {
        var width: Double
        var height: Double
        var titleHeight: Double
        var attributeHeight: Double
    }

    func svg(prefix: String) -> String {
        guard !classes.isEmpty else { return "" }
        let lineHeight = 19.0
        func n(_ value: Double) -> String { DiagramText.number(value) }

        var layouts: [Layout] = []
        for box in classes {
            var widths = [DiagramText.width(box.name, size: 14, bold: true) + 8]
            if let annotation = box.annotation { widths.append(DiagramText.width("<<\(annotation)>>", size: 12)) }
            widths += (box.attributes + box.methods).map { DiagramText.width($0, size: 13) }
            let titleHeight = (box.annotation == nil ? 0 : 18.0) + 30
            let attributeHeight = max(Double(box.attributes.count) * lineHeight + 12, 12)
            let methodHeight = max(Double(box.methods.count) * lineHeight + 12, 12)
            layouts.append(Layout(
                width: max((widths.max() ?? 0) + 30, 96),
                height: titleHeight + attributeHeight + methodHeight,
                titleHeight: titleHeight,
                attributeHeight: attributeHeight
            ))
        }

        func position(of name: String) -> Int? { classes.firstIndex { $0.name == name } }
        var layoutEdges: [GraphLayout.Edge] = []
        var drawn: [Relation] = []
        for relation in relations {
            guard var a = position(of: relation.from), var b = position(of: relation.to) else { continue }
            var normalised = relation
            // Put the parent (the end that carries a triangle or diamond) above its child.
            if relation.fromMarker == .none, relation.toMarker == .triangle || relation.toMarker == .diamond || relation.toMarker == .filledDiamond {
                swap(&a, &b)
                normalised = Relation(
                    from: relation.to, to: relation.from, fromMarker: relation.toMarker, toMarker: relation.fromMarker,
                    isDashed: relation.isDashed, label: relation.label, fromCardinality: relation.toCardinality, toCardinality: relation.fromCardinality
                )
            }
            let label = normalised.label.map { DiagramText.size(of: [$0], fontSize: 12) }
            layoutEdges.append(GraphLayout.Edge(from: a, to: b, labelSize: label.map { CGSize(width: $0.width + 10, height: $0.height + 4) }))
            drawn.append(normalised)
        }
        let layout = GraphLayout.layout(
            nodes: layouts.map { GraphLayout.Node(size: CGSize(width: $0.width, height: $0.height)) },
            edges: layoutEdges, direction: direction, nodeGap: 48, rankGap: 80
        )

        var body = ""
        for (index, relation) in drawn.enumerated() {
            let route = layout.routes[index]
            guard route.points.count >= 2 else { continue }
            func marker(_ marker: Marker) -> String? {
                switch marker {
                case .none: nil
                case .triangle: "\(prefix)-triangle"
                case .diamond: "\(prefix)-diamond"
                case .filledDiamond: "\(prefix)-diamond-filled"
                case .arrow: "\(prefix)-open"
                }
            }
            var attributes = "fill=\"none\" stroke=\"\(DiagramTheme.line)\" stroke-width=\"1.5\""
            if relation.isDashed { attributes += " stroke-dasharray=\"6 4\"" }
            if let start = marker(relation.fromMarker) { attributes += " marker-start=\"url(#\(start))\"" }
            if let end = marker(relation.toMarker) { attributes += " marker-end=\"url(#\(end))\"" }
            if route.points.first == route.points.last {
                let center = layout.centers[layoutEdges[index].from]
                let right = center.x + layouts[layoutEdges[index].from].width / 2
                body += "<path d=\"M\(n(right)),\(n(center.y - 10)) h30 v20 h-30\" \(attributes)/>"
            } else {
                body += "<path d=\"\(GraphLayout.path(route.points))\" \(attributes)/>"
            }
            if let label = relation.label, let at = route.labelPosition {
                body += "<rect x=\"\(n(at.x - DiagramText.width(label, size: 12) / 2 - 5))\" y=\"\(n(at.y - 10))\" width=\"\(n(DiagramText.width(label, size: 12) + 10))\" height=\"20\" rx=\"3\" fill=\"#ffffff\" fill-opacity=\"0.92\"/>"
                body += DiagramText.centred([label], at: at, fontSize: 12, fill: DiagramTheme.mutedText)
            }
            for (text, point, neighbour) in [(relation.fromCardinality, route.points[0], route.points[1]), (relation.toCardinality, route.points[route.points.count - 1], route.points[route.points.count - 2])] {
                guard let text else { continue }
                let dx = neighbour.x - point.x, dy = neighbour.y - point.y
                let length = max(sqrt(dx * dx + dy * dy), 1)
                let anchor = CGPoint(x: point.x + dx / length * 20 - dy / length * 12, y: point.y + dy / length * 20 + dx / length * 12)
                body += DiagramText.centred([text], at: anchor, fontSize: 12, fill: DiagramTheme.mutedText)
            }
        }

        for (index, box) in classes.enumerated() {
            let metrics = layouts[index]
            let center = layout.centers[index]
            let x = center.x - metrics.width / 2, y = center.y - metrics.height / 2
            body += "<rect x=\"\(n(x))\" y=\"\(n(y))\" width=\"\(n(metrics.width))\" height=\"\(n(metrics.height))\" fill=\"\(DiagramTheme.nodeFill)\" stroke=\"\(DiagramTheme.nodeStroke)\" stroke-width=\"1.5\"/>"
            var cursor = y
            if let annotation = box.annotation {
                body += DiagramText.centred(["<<\(annotation)>>"], at: CGPoint(x: center.x, y: cursor + 14), fontSize: 12, fill: DiagramTheme.mutedText)
                cursor += 18
            }
            body += DiagramText.centred([box.name], at: CGPoint(x: center.x, y: cursor + 16), fontSize: 14, bold: true)
            cursor = y + metrics.titleHeight
            body += "<line x1=\"\(n(x))\" y1=\"\(n(cursor))\" x2=\"\(n(x + metrics.width))\" y2=\"\(n(cursor))\" stroke=\"\(DiagramTheme.nodeStroke)\" stroke-width=\"1.5\"/>"
            for (row, attribute) in box.attributes.enumerated() {
                body += DiagramText.centred([attribute], at: CGPoint(x: x + 12, y: cursor + 6 + Double(row) * lineHeight + lineHeight / 2), fontSize: 13, anchor: "start")
            }
            cursor += metrics.attributeHeight
            body += "<line x1=\"\(n(x))\" y1=\"\(n(cursor))\" x2=\"\(n(x + metrics.width))\" y2=\"\(n(cursor))\" stroke=\"\(DiagramTheme.nodeStroke)\" stroke-width=\"1.5\"/>"
            for (row, method) in box.methods.enumerated() {
                body += DiagramText.centred([method], at: CGPoint(x: x + 12, y: cursor + 6 + Double(row) * lineHeight + lineHeight / 2), fontSize: 13, anchor: "start")
            }
        }
        return "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 \(n(layout.size.width)) \(n(layout.size.height))\" width=\"\(n(layout.size.width))\" height=\"\(n(layout.size.height))\" font-family=\"-apple-system, 'SF Pro Text', Helvetica, Arial, sans-serif\">\n\(SVGMarkers.definitions(prefix: prefix))\n\(body)</svg>"
    }
}
