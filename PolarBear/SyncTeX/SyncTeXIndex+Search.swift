//
//  SyncTeXIndex+Search.swift
//  PolarBear
//

import CoreGraphics
import Foundation

/// The two directions of SyncTeX: source → PDF and PDF → source.
extension SyncTeXIndex {
    struct SourceLocation: Sendable {
        /// The path as the engine recorded it (usually absolute).
        var file: String
        var line: Int
    }

    struct PDFLocation: Sendable {
        var page: Int
        /// Rectangles in PDF points, measured from the top-left of the page.
        var rects: [CGRect]

        var union: CGRect {
            rects.dropFirst().reduce(rects.first ?? .zero) { $0.union($1) }
        }
    }

    /// The tag the engine gave `path`, matched on the full path.
    func tag(forPath path: String) -> Int? {
        inputs.first { _, recorded in recorded == path || (recorded as NSString).standardizingPath == path }?.key
    }

    // MARK: Source → PDF

    /// Where the text of `line` in the file with `tag` ended up. If that exact line produced
    /// nothing (a comment, a blank line), the nearest line that did is used.
    func pdfLocation(tag: Int, line: Int) -> PDFLocation? {
        var lines: Set<Int> = []
        for page in pages {
            for node in page where node.tag == tag && node.line > 0 { lines.insert(node.line) }
        }
        guard !lines.isEmpty else { return nil }
        let target = lines.contains(line)
            ? line
            : (lines.filter { $0 > line }.min() ?? lines.filter { $0 < line }.max() ?? line)

        for (pageIndex, nodes) in pages.enumerated() {
            var rects: [CGRect] = []
            for node in nodes where node.tag == tag && node.line == target {
                switch node.kind {
                case .hbox, .vbox:
                    if node.width > 0 || node.height > 0 { rects.append(Self.rect(of: node)) }
                case .point:
                    if let parent = node.parent {
                        rects.append(Self.rect(of: nodes[parent]))
                    } else {
                        rects.append(CGRect(x: node.x, y: node.y - 10, width: 10, height: 12))
                    }
                }
            }
            if !rects.isEmpty { return PDFLocation(page: pageIndex, rects: rects) }
        }
        return nil
    }

    // MARK: PDF → source

    /// The source line of the spot at (`x`, `y`) on page `page` (points from the top-left).
    func sourceLocation(page: Int, x: Double, y: Double) -> SourceLocation? {
        guard pages.indices.contains(page) else { return nil }
        let nodes = pages[page]
        let point = CGPoint(x: x, y: y)

        var best: (index: Int, distance: Double, area: Double)?
        for (offset, node) in nodes.enumerated() where node.kind == .hbox && node.width > 0 && node.height + node.depth > 0 {
            let rect = Self.rect(of: node)
            let distance = Self.distance(from: point, to: rect)
            let area = Double(rect.width * rect.height)
            if let current = best {
                if distance < current.distance || (distance == current.distance && area < current.area) {
                    best = (offset, distance, area)
                }
            } else {
                best = (offset, distance, area)
            }
        }
        guard let box = best.map({ nodes[$0.index] }), let boxIndex = best?.index else { return nil }

        // Prefer the element of the line closest to the click: it knows its own source line.
        let children = nodes.enumerated().filter { $0.element.parent == boxIndex && $0.element.line > 0 }
        let closest = children.min { lhs, rhs in
            abs(lhs.element.x - x) < abs(rhs.element.x - x)
        }?.element ?? box

        guard let file = inputs[closest.tag] else { return nil }
        return SourceLocation(file: file, line: closest.line)
    }

    // MARK: Geometry

    private static func rect(of node: Node) -> CGRect {
        CGRect(x: node.x, y: node.y - node.height, width: max(node.width, 1), height: node.height + node.depth)
    }

    private static func distance(from point: CGPoint, to rect: CGRect) -> Double {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return Double((dx * dx + dy * dy).squareRoot())
    }
}
