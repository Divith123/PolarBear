//
//  PieChart.swift
//  PolarBear
//

import CoreGraphics
import Foundation

/// A Mermaid `pie` chart.
nonisolated struct PieChart {
    var title: String?
    var showsData = false
    var slices: [(label: String, value: Double)] = []

    static func parse(_ lines: [String]) -> PieChart {
        var chart = PieChart()
        for (offset, raw) in lines.enumerated() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("%%") { continue }
            if offset == 0 {
                chart.showsData = line.lowercased().contains("showdata")
                if let match = line.prefixMatch(of: /^pie.*?\btitle\s+(.+)$/.ignoresCase()) { chart.title = String(match.1) }
                continue
            }
            if line.lowercased().hasPrefix("title") {
                chart.title = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                continue
            }
            if line.lowercased() == "showdata" {
                chart.showsData = true
                continue
            }
            if let match = line.prefixMatch(of: /^"?([^":]+?)"?\s*:\s*(-?[0-9]*\.?[0-9]+)\s*$/), let value = Double(match.2), value > 0 {
                chart.slices.append((String(match.1), value))
            }
        }
        return chart
    }

    func svg() -> String {
        guard !slices.isEmpty else { return "" }
        func n(_ value: Double) -> String { DiagramText.number(value) }
        let total = slices.reduce(0) { $0 + $1.value }
        let radius = 140.0
        let legendEntries = slices.map { slice -> String in
            showsData ? "\(slice.label) [\(DiagramText.number(slice.value))]" : slice.label
        }
        let legendWidth = (legendEntries.map { DiagramText.width($0, size: 13) }.max() ?? 0) + 34
        let titleHeight = title == nil ? 0.0 : 36.0
        let cx = radius + 24, cy = radius + 24 + titleHeight
        let width = cx + radius + 34 + legendWidth + 16
        let height = cy + radius + 24

        var markup = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 \(n(width)) \(n(height))\" width=\"\(n(width))\" height=\"\(n(height))\" font-family=\"-apple-system, 'SF Pro Text', Helvetica, Arial, sans-serif\">\n"
        if let title { markup += DiagramText.centred([title], at: CGPoint(x: cx, y: 22), fontSize: 16, bold: true) }

        var angle = -Double.pi / 2
        for (index, slice) in slices.enumerated() {
            let fraction = slice.value / total
            let end = angle + fraction * 2 * Double.pi
            let color = DiagramTheme.palette[index % DiagramTheme.palette.count]
            if slices.count == 1 {
                markup += "<circle cx=\"\(n(cx))\" cy=\"\(n(cy))\" r=\"\(n(radius))\" fill=\"\(color)\" stroke=\"#ffffff\" stroke-width=\"2\"/>"
            } else {
                let x1 = cx + radius * cos(angle), y1 = cy + radius * sin(angle)
                let x2 = cx + radius * cos(end), y2 = cy + radius * sin(end)
                let large = fraction > 0.5 ? 1 : 0
                markup += "<path d=\"M\(n(cx)),\(n(cy)) L\(n(x1)),\(n(y1)) A\(n(radius)),\(n(radius)) 0 \(large) 1 \(n(x2)),\(n(y2)) Z\" fill=\"\(color)\" stroke=\"#ffffff\" stroke-width=\"2\"/>"
            }
            if fraction >= 0.03 {
                let middle = (angle + end) / 2
                let label = CGPoint(x: cx + radius * 0.68 * cos(middle), y: cy + radius * 0.68 * sin(middle))
                markup += DiagramText.centred(["\(Int((fraction * 100).rounded()))%"], at: label, fontSize: 13, bold: true, fill: "#ffffff")
            }
            angle = end
        }

        var legendY = cy - Double(slices.count) * 13
        let legendX = cx + radius + 34
        for (index, entry) in legendEntries.enumerated() {
            let color = DiagramTheme.palette[index % DiagramTheme.palette.count]
            markup += "<rect x=\"\(n(legendX))\" y=\"\(n(legendY - 7))\" width=\"14\" height=\"14\" rx=\"3\" fill=\"\(color)\"/>"
            markup += DiagramText.centred([entry], at: CGPoint(x: legendX + 22, y: legendY), fontSize: 13, anchor: "start")
            legendY += 26
        }
        return markup + "</svg>"
    }
}
