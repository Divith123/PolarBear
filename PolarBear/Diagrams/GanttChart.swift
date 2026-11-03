//
//  GanttChart.swift
//  PolarBear
//

import CoreGraphics
import Foundation

/// A Mermaid `gantt` chart: sections of tasks on a time axis.
nonisolated struct GanttChart {
    enum State { case normal, done, active, critical }

    struct Task {
        var name: String
        var id: String?
        var section: Int
        var start: Double // days since the reference date
        var end: Double
        var state = State.normal
        var isMilestone = false
    }

    var title: String?
    var sections: [String] = []
    var tasks: [Task] = []
    var referenceDate = Date(timeIntervalSince1970: 0)

    // MARK: Parsing

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }

    private static func date(_ text: String) -> Date? {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    private static func duration(_ text: String) -> Double? {
        guard let match = text.prefixMatch(of: /^(\d+(?:\.\d+)?)\s*(ms|s|m|h|d|w|M|y)$/), let value = Double(match.1) else { return nil }
        switch match.2 {
        case "ms": return value / 86_400_000
        case "s": return value / 86_400
        case "m": return value / 1_440
        case "h": return value / 24
        case "d": return value
        case "w": return value * 7
        case "M": return value * 30
        default: return value * 365
        }
    }

    static func parse(_ lines: [String]) -> GanttChart {
        var chart = GanttChart()
        var origin: Date?
        var pending: [(name: String, spec: String, section: Int)] = []
        var currentSection = -1

        for (offset, raw) in lines.enumerated() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("%%") || (offset == 0 && line.lowercased().hasPrefix("gantt")) { continue }
            let lowered = line.lowercased()
            if lowered.hasPrefix("title") {
                chart.title = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            } else if lowered.hasPrefix("section") {
                chart.sections.append(String(line.dropFirst(7)).trimmingCharacters(in: .whitespaces))
                currentSection = chart.sections.count - 1
            } else if lowered.hasPrefix("dateformat") || lowered.hasPrefix("axisformat") || lowered.hasPrefix("excludes") || lowered.hasPrefix("includes")
                        || lowered.hasPrefix("todaymarker") || lowered.hasPrefix("tickinterval") || lowered.hasPrefix("weekday") || lowered.hasPrefix("click") {
                continue
            } else if let colon = line.lastIndex(of: ":") {
                if currentSection < 0 {
                    chart.sections.append("")
                    currentSection = 0
                }
                let name = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
                pending.append((name, String(line[line.index(after: colon)...]), currentSection))
            }
        }

        // Resolve start and end days in order, so `after id` can refer to earlier tasks.
        var ids: [String: Task] = [:]
        var previousEnd: Double?
        for item in pending {
            var tokens = item.spec.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            var state = State.normal
            var milestone = false
            while let first = tokens.first, ["done", "active", "crit", "milestone"].contains(first) {
                switch first {
                case "done": state = .done
                case "active": state = .active
                case "crit": state = .critical
                default: milestone = true
                }
                tokens.removeFirst()
            }
            var id: String?
            if tokens.count >= 2, let first = tokens.first, date(first) == nil, duration(first) == nil, !first.hasPrefix("after ") {
                id = first
                tokens.removeFirst()
            }

            func resolveStart(_ token: String) -> Double? {
                if let day = date(token) {
                    if origin == nil { origin = day }
                    return day.timeIntervalSince(origin ?? day) / 86_400
                }
                if token.hasPrefix("after ") {
                    let names = token.dropFirst(6).split(separator: " ").map(String.init)
                    let ends = names.compactMap { ids[$0]?.end }
                    return ends.max()
                }
                return nil
            }

            var start: Double?
            var end: Double?
            if tokens.count >= 2 {
                start = resolveStart(tokens[0])
                if let length = duration(tokens[1]) {
                    end = (start ?? previousEnd ?? 0) + length
                } else if let day = date(tokens[1]) {
                    if origin == nil { origin = day }
                    end = day.timeIntervalSince(origin ?? day) / 86_400
                }
            } else if let only = tokens.first {
                if let length = duration(only) {
                    start = previousEnd ?? 0
                    end = (start ?? 0) + length
                } else if let day = resolveStart(only) {
                    start = day
                    end = day + 1
                }
            }
            let resolvedStart = start ?? previousEnd ?? 0
            var resolvedEnd = end ?? resolvedStart + 1
            if milestone { resolvedEnd = resolvedStart }
            var task = Task(name: item.name, id: id, section: item.section, start: resolvedStart, end: resolvedEnd, state: state, isMilestone: milestone)
            if task.end < task.start { swap(&task.start, &task.end) }
            if let id { ids[id] = task }
            chart.tasks.append(task)
            previousEnd = task.end
        }
        chart.referenceDate = origin ?? Date(timeIntervalSince1970: 0)
        return chart
    }

    // MARK: Drawing

    func svg() -> String {
        guard !tasks.isEmpty else { return "" }
        func n(_ value: Double) -> String { DiagramText.number(value) }

        let first = tasks.map(\.start).min() ?? 0
        let last = max(tasks.map(\.end).max() ?? 1, first + 1)
        let span = last - first
        let labelColumn = (sections.map { DiagramText.width($0, size: 13, bold: true) }.max() ?? 0) + 24
        let plotLeft = max(labelColumn, 40.0)
        let plotWidth = 640.0
        let rowHeight = 32.0, topAxis = 44.0 + (title == nil ? 0 : 30)
        func xPosition(_ day: Double) -> Double { plotLeft + (day - first) / span * plotWidth }
        // Names that do not fit inside their bar are written after it; leave room for them.
        var rightEdge = plotLeft + plotWidth + 24
        for task in tasks {
            let nameWidth = DiagramText.width(task.name, size: 12.5)
            let barWidth = xPosition(task.end) - xPosition(task.start)
            if task.isMilestone {
                rightEdge = max(rightEdge, xPosition(task.start) + 18 + nameWidth + 16)
            } else if nameWidth + 14 > max(barWidth, 3) {
                rightEdge = max(rightEdge, xPosition(task.end) + 8 + nameWidth + 16)
            }
        }
        let width = rightEdge
        let height = topAxis + Double(tasks.count) * rowHeight + 16

        var markup = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 \(n(width)) \(n(height))\" width=\"\(n(width))\" height=\"\(n(height))\" font-family=\"-apple-system, 'SF Pro Text', Helvetica, Arial, sans-serif\">\n"
        if let title { markup += DiagramText.centred([title], at: CGPoint(x: width / 2, y: 18), fontSize: 16, bold: true) }

        // Section bands.
        var row = 0
        for (index, section) in sections.enumerated() {
            let count = tasks.filter { $0.section == index }.count
            guard count > 0 else { continue }
            let top = topAxis + Double(row) * rowHeight
            markup += "<rect x=\"0\" y=\"\(n(top))\" width=\"\(n(width))\" height=\"\(n(Double(count) * rowHeight))\" fill=\"\(index % 2 == 0 ? "#f6f7ff" : "#ffffff")\"/>"
            if !section.isEmpty {
                markup += DiagramText.centred([section], at: CGPoint(x: 12, y: top + Double(count) * rowHeight / 2), fontSize: 13, bold: true, fill: DiagramTheme.mutedText, anchor: "start")
            }
            row += count
        }

        // Time axis.
        let calendar = Self.calendar
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let step: Double = span <= 16 ? 1 : (span <= 70 ? 7 : (span <= 400 ? 30 : 365))
        formatter.dateFormat = span <= 70 ? "MMM d" : "MMM yyyy"
        var day = (first / step).rounded(.up) * step
        if span > 70 { day = first }
        let axisBottom = topAxis + Double(tasks.count) * rowHeight
        while day <= last + 0.001 {
            let x = xPosition(day)
            markup += "<line x1=\"\(n(x))\" y1=\"\(n(topAxis - 6))\" x2=\"\(n(x))\" y2=\"\(n(axisBottom))\" stroke=\"#e1e4e8\" stroke-width=\"1\"/>"
            let date = referenceDate.addingTimeInterval(day * 86_400)
            markup += DiagramText.centred([formatter.string(from: date)], at: CGPoint(x: x, y: topAxis - 18), fontSize: 11.5, fill: DiagramTheme.mutedText)
            day += step
        }

        // Bars.
        for (index, task) in tasks.enumerated() {
            let top = topAxis + Double(index) * rowHeight + 5
            let x1 = xPosition(task.start), x2 = xPosition(task.end)
            let barWidth = max(x2 - x1, task.isMilestone ? 0 : 3)
            let fill: String, stroke: String, textColor: String
            switch task.state {
            case .normal: (fill, stroke, textColor) = ("#8f93e0", "#6c70c8", "#ffffff")
            case .active: (fill, stroke, textColor) = ("#d6d9ff", "#6c70c8", DiagramTheme.text)
            case .done: (fill, stroke, textColor) = ("#d4d8de", "#9aa0a6", DiagramTheme.mutedText)
            case .critical: (fill, stroke, textColor) = ("#f5a3a3", "#d83b3b", DiagramTheme.text)
            }
            if task.isMilestone {
                let cy = top + 11
                markup += "<polygon points=\"\(n(x1)),\(n(cy - 11)) \(n(x1 + 11)),\(n(cy)) \(n(x1)),\(n(cy + 11)) \(n(x1 - 11)),\(n(cy))\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"1.5\"/>"
                markup += DiagramText.centred([task.name], at: CGPoint(x: x1 + 18, y: cy), fontSize: 12.5, fill: DiagramTheme.text, anchor: "start")
                continue
            }
            markup += "<rect x=\"\(n(x1))\" y=\"\(n(top))\" width=\"\(n(barWidth))\" height=\"22\" rx=\"4\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"1.3\"/>"
            let nameWidth = DiagramText.width(task.name, size: 12.5)
            if nameWidth + 14 <= barWidth {
                markup += DiagramText.centred([task.name], at: CGPoint(x: x1 + barWidth / 2, y: top + 11), fontSize: 12.5, fill: textColor)
            } else {
                markup += DiagramText.centred([task.name], at: CGPoint(x: x1 + barWidth + 8, y: top + 11), fontSize: 12.5, fill: DiagramTheme.text, anchor: "start")
            }
        }
        return markup + "</svg>"
    }
}
