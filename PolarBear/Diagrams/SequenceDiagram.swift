//
//  SequenceDiagram.swift
//  PolarBear
//

import CoreGraphics
import Foundation

/// A Mermaid `sequenceDiagram`: parsed into events, then drawn as SVG.
nonisolated struct SequenceDiagram {
    struct Participant {
        var id: String
        var label: String
        var isActor = false
    }

    enum Line { case solid, dashed }
    enum Head { case arrow, open, cross, none }

    enum NotePlacement { case leftOf(String), rightOf(String), over([String]) }

    enum Event {
        case message(from: String, to: String, text: String, line: Line, head: Head, activate: Bool, deactivate: Bool)
        case note(NotePlacement, String)
        case activate(String)
        case deactivate(String)
        case blockStart(kind: String, label: String)
        case blockElse(label: String)
        case blockEnd
    }

    /// A `loop`, `alt` … block being drawn.
    struct OpenBlock {
        var kind: String
        var label: String
        var top: Double
        var low: Int
        var high: Int
        var separators: [(Double, String)]
    }

    var participants: [Participant] = []
    var events: [Event] = []
    var title: String?
    var numbersMessages = false

    // MARK: Parsing

    static func parse(_ lines: [String]) -> SequenceDiagram {
        var diagram = SequenceDiagram()

        func ensure(_ id: String) {
            if !diagram.participants.contains(where: { $0.id == id }) {
                diagram.participants.append(Participant(id: id, label: id))
            }
        }

        for (offset, raw) in lines.enumerated() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("%%") || (offset == 0 && line.lowercased().hasPrefix("sequencediagram")) { continue }
            let lowered = line.lowercased()

            if lowered == "autonumber" || lowered.hasPrefix("autonumber ") {
                diagram.numbersMessages = true
                continue
            }
            if lowered.hasPrefix("title") {
                diagram.title = String(line.dropFirst(5)).trimmingCharacters(in: CharacterSet(charactersIn: ": "))
                continue
            }
            if let match = line.prefixMatch(of: /^(participant|actor)\s+(\S+?)(?:\s+as\s+(.+))?$/) {
                let id = String(match.2)
                let label = match.3.map { String($0).trimmingCharacters(in: .whitespaces) } ?? id
                if let existing = diagram.participants.firstIndex(where: { $0.id == id }) {
                    diagram.participants[existing].label = label
                    diagram.participants[existing].isActor = match.1 == "actor"
                } else {
                    diagram.participants.append(Participant(id: id, label: label, isActor: match.1 == "actor"))
                }
                continue
            }
            if let match = line.prefixMatch(of: /^(activate|deactivate)\s+(\S+)\s*$/) {
                ensure(String(match.2))
                diagram.events.append(match.1 == "activate" ? .activate(String(match.2)) : .deactivate(String(match.2)))
                continue
            }
            if let match = line.prefixMatch(of: /^note\s+(left of|right of|over)\s+([^:]+):\s*(.*)$/.ignoresCase()) {
                let ids = match.2.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                for id in ids { ensure(id) }
                let placement: NotePlacement
                switch match.1.lowercased() {
                case "left of": placement = .leftOf(ids[0])
                case "right of": placement = .rightOf(ids[0])
                default: placement = .over(ids)
                }
                diagram.events.append(.note(placement, String(match.3)))
                continue
            }
            if let match = line.prefixMatch(of: /^(loop|alt|opt|par|critical|break|rect|box)\b\s*(.*)$/) {
                if match.1 == "box" || match.1 == "rect" {
                    // Grouping boxes only colour the background; their content is still drawn.
                    diagram.events.append(.blockStart(kind: "", label: ""))
                } else {
                    diagram.events.append(.blockStart(kind: String(match.1), label: String(match.2)))
                }
                continue
            }
            if let match = line.prefixMatch(of: /^(else|and|option)\b\s*(.*)$/) {
                diagram.events.append(.blockElse(label: String(match.2)))
                continue
            }
            if lowered == "end" {
                diagram.events.append(.blockEnd)
                continue
            }

            // A->>B: text
            if let match = line.prefixMatch(of: /^(\S+?)\s*(-->>|->>|-->|->|--x|-x|--\)|-\))\s*([+-])?\s*([^\s:]+)\s*:\s*(.*)$/) {
                let from = String(match.1), to = String(match.4)
                ensure(from)
                ensure(to)
                let op = String(match.2)
                let head: Head = op.hasSuffix(">>") ? .arrow : (op.hasSuffix("x") ? .cross : (op.hasSuffix(")") ? .open : .none))
                let sign = match.3.map(String.init)
                diagram.events.append(.message(
                    from: from, to: to, text: String(match.5),
                    line: op.hasPrefix("--") ? .dashed : .solid, head: head,
                    activate: sign == "+", deactivate: sign == "-"
                ))
            }
        }
        return diagram
    }

    // MARK: Drawing

    func svg(prefix: String) -> String {
        guard !participants.isEmpty else { return "" }
        let font = 13.0
        func n(_ value: Double) -> String { DiagramText.number(value) }

        // Horizontal positions.
        let boxHeight = 38.0
        let boxWidths = participants.map { max(DiagramText.size(of: DiagramText.lines($0.label), fontSize: 14, bold: true).width + 32, 96) }
        var gaps = Array(repeating: 0.0, count: max(participants.count - 1, 0))
        func index(_ id: String) -> Int { participants.firstIndex { $0.id == id } ?? 0 }
        for i in gaps.indices { gaps[i] = (boxWidths[i] + boxWidths[i + 1]) / 2 + 28 }
        for event in events {
            switch event {
            case .message(let from, let to, let text, _, _, _, _):
                let a = index(from), b = index(to)
                let width = DiagramText.size(of: DiagramText.lines(text), fontSize: font).width + 46
                if a == b {
                    if a < gaps.count { gaps[a] = max(gaps[a], width + 30) }
                } else {
                    let low = min(a, b), high = max(a, b)
                    let current = gaps[low..<high].reduce(0, +)
                    if width > current {
                        let extra = (width - current) / Double(high - low)
                        for i in low..<high { gaps[i] += extra }
                    }
                }
            case .note(let placement, let text):
                let width = DiagramText.size(of: DiagramText.lines(text), fontSize: font).width + 28
                switch placement {
                case .over(let ids) where ids.count > 1:
                    let a = index(ids[0]), b = index(ids[1])
                    let low = min(a, b), high = max(a, b)
                    let current = gaps[low..<high].reduce(0, +)
                    if width > current + 40, high > low {
                        let extra = (width - current - 40) / Double(high - low)
                        for i in low..<high { gaps[i] += extra }
                    }
                case .rightOf(let id):
                    let i = index(id)
                    if i < gaps.count { gaps[i] = max(gaps[i], width / 2 + boxWidths[i] / 2 + 20) }
                case .leftOf(let id):
                    let i = index(id)
                    if i > 0 { gaps[i - 1] = max(gaps[i - 1], width / 2 + boxWidths[i] / 2 + 20) }
                default: break
                }
            default: break
            }
        }
        var centers = [boxWidths[0] / 2 + 24]
        for i in gaps.indices { centers.append(centers[i] + gaps[i]) }

        // Vertical flow.
        var y = boxHeight + 36
        var extentLeft = 0.0
        var extentRight = (centers.last ?? 0) + (boxWidths.last ?? 0) / 2 + 24
        var background = ""
        var foreground = ""
        var activations: [String: [Double]] = [:]
        var activationRects = ""
        var messageNumber = 0
        var blocks: [OpenBlock] = []

        func touch(_ i: Int) {
            for k in blocks.indices { blocks[k].low = min(blocks[k].low, i); blocks[k].high = max(blocks[k].high, i) }
        }
        func lifelineX(_ id: String, towards other: Double) -> Double {
            let base = centers[index(id)]
            let level = activations[id]?.count ?? 0
            guard level > 0 else { return base }
            return base + (other >= base ? 5 + Double(level - 1) * 3 : -5 - Double(level - 1) * 3)
        }
        func endActivation(_ id: String, at bottom: Double) {
            guard var stack = activations[id], let top = stack.popLast() else { return }
            let level = stack.count
            let x = centers[index(id)] - 5 + Double(level) * 3
            activationRects += "<rect x=\"\(n(x))\" y=\"\(n(top))\" width=\"10\" height=\"\(n(max(bottom - top, 4)))\" fill=\"#e6e8ff\" stroke=\"\(DiagramTheme.nodeStroke)\" stroke-width=\"1.2\"/>"
            activations[id] = stack
        }

        for event in events {
            switch event {
            case .message(let from, let to, let text, let line, let head, let activate, let deactivate):
                let a = index(from), b = index(to)
                touch(a)
                touch(b)
                messageNumber += 1
                let labelLines = DiagramText.lines(text)
                let labelHeight = Double(labelLines.count) * font * 1.36
                let dash = line == .dashed ? " stroke-dasharray=\"6 4\"" : ""
                let marker: String
                switch head {
                case .arrow: marker = " marker-end=\"url(#\(prefix)-arrow)\""
                case .open: marker = " marker-end=\"url(#\(prefix)-open)\""
                case .cross: marker = " marker-end=\"url(#\(prefix)-cross)\""
                case .none: marker = ""
                }
                if a == b {
                    let x = lifelineX(from, towards: centers[a] + 1)
                    y += 8
                    let top = y + 4
                    foreground += "<path d=\"M\(n(x)),\(n(top)) h40 v24 h-40\" fill=\"none\" stroke=\"\(DiagramTheme.line)\" stroke-width=\"1.5\"\(dash)\(marker)/>"
                    foreground += DiagramText.centred(labelLines, at: CGPoint(x: x + 48, y: top + 12), fontSize: font, fill: DiagramTheme.text, anchor: "start")
                    extentRight = max(extentRight, x + 56 + DiagramText.size(of: labelLines, fontSize: font).width)
                    if numbersMessages { foreground += badge(messageNumber, at: CGPoint(x: x + 1, y: top)) }
                    y += 44
                    if activate { activations[from, default: []].append(top + 20) }
                    if deactivate { endActivation(from, at: top + 24) }
                } else {
                    y += labelHeight + 12
                    let x1 = lifelineX(from, towards: centers[b]), x2 = lifelineX(to, towards: centers[a])
                    if activate { activations[to, default: []].append(y) }
                    foreground += DiagramText.centred(labelLines, at: CGPoint(x: (centers[a] + centers[b]) / 2, y: y - 9 - labelHeight / 2 + 4), fontSize: font, fill: DiagramTheme.text)
                    foreground += "<path d=\"M\(n(x1)),\(n(y)) L\(n(x2)),\(n(y))\" fill=\"none\" stroke=\"\(DiagramTheme.line)\" stroke-width=\"1.5\"\(dash)\(marker)/>"
                    if numbersMessages { foreground += badge(messageNumber, at: CGPoint(x: x1 + (x2 > x1 ? 14 : -14), y: y)) }
                    if deactivate { endActivation(from, at: y) }
                    y += 20
                }
            case .note(let placement, let text):
                let lines = DiagramText.lines(text)
                let size = DiagramText.size(of: lines, fontSize: font)
                let width = size.width + 24, height = size.height + 14
                var x: Double
                switch placement {
                case .leftOf(let id): x = centers[index(id)] - 14 - width; touch(index(id))
                case .rightOf(let id): x = centers[index(id)] + 14; touch(index(id))
                case .over(let ids):
                    let a = index(ids[0]), b = index(ids.last ?? ids[0])
                    let middle = (centers[a] + centers[b]) / 2
                    let spread = abs(centers[b] - centers[a]) + 40
                    let full = max(width, spread)
                    x = middle - full / 2
                    touch(a)
                    touch(b)
                    y += 6
                    foreground += note(lines, x: x, y: y, width: full, height: height, font: font)
                    extentLeft = min(extentLeft, x - 12)
                    extentRight = max(extentRight, x + full + 12)
                    y += height + 14
                    continue
                }
                y += 6
                foreground += note(lines, x: x, y: y, width: width, height: height, font: font)
                extentLeft = min(extentLeft, x - 12)
                extentRight = max(extentRight, x + width + 12)
                y += height + 14
            case .activate(let id):
                activations[id, default: []].append(y)
            case .deactivate(let id):
                endActivation(id, at: y - 8)
            case .blockStart(let kind, let label):
                y += 10
                blocks.append(OpenBlock(kind: kind, label: label, top: y, low: participants.count, high: -1, separators: []))
                y += kind.isEmpty ? 4 : 26
            case .blockElse(let label):
                if !blocks.isEmpty {
                    y += 6
                    blocks[blocks.count - 1].separators.append((y, label))
                    y += 24
                }
            case .blockEnd:
                if let block = blocks.popLast(), block.high >= block.low {
                    let left = centers[block.low] - 26, right = centers[block.high] + 26
                    if block.kind.isEmpty {
                        background += "<rect x=\"\(n(left))\" y=\"\(n(block.top))\" width=\"\(n(right - left))\" height=\"\(n(y - block.top))\" fill=\"#f3f4f6\" opacity=\"0.8\"/>"
                    } else {
                        foreground += frame(block, left: left, right: right, bottom: y, font: font)
                    }
                    if !blocks.isEmpty { touch(block.low); touch(block.high) }
                }
                y += 14
            }
        }
        // Anything still active ends at the bottom.
        for id in Array(activations.keys) { while !(activations[id]?.isEmpty ?? true) { endActivation(id, at: y) } }
        y += 8

        // Lifelines and the actor boxes, at the top and again at the bottom.
        var lifelines = ""
        var boxes = ""
        for (i, participant) in participants.enumerated() {
            let x = centers[i]
            lifelines += "<line x1=\"\(n(x))\" y1=\"\(n(boxHeight))\" x2=\"\(n(x))\" y2=\"\(n(y))\" stroke=\"#9aa0a6\" stroke-width=\"1.2\" stroke-dasharray=\"5 5\"/>"
            boxes += participantBox(participant, centerX: x, top: 0, width: boxWidths[i], height: boxHeight)
            boxes += participantBox(participant, centerX: x, top: y, width: boxWidths[i], height: boxHeight)
        }
        let width = extentRight - extentLeft
        let titleHeight = title == nil ? 0.0 : 30.0
        var markup = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"\(n(extentLeft)) \(n(-titleHeight)) \(n(width)) \(n(y + boxHeight + titleHeight + 6))\" width=\"\(n(width))\" height=\"\(n(y + boxHeight + titleHeight + 6))\" font-family=\"-apple-system, 'SF Pro Text', Helvetica, Arial, sans-serif\">\n"
        markup += SVGMarkers.definitions(prefix: prefix) + "\n"
        if let title { markup += DiagramText.centred([title], at: CGPoint(x: (extentLeft + extentRight) / 2, y: -titleHeight / 2 - 2), fontSize: 15, bold: true) }
        markup += background + lifelines + activationRects + boxes + foreground + "</svg>"
        return markup
    }

    private func badge(_ number: Int, at point: CGPoint) -> String {
        "<circle cx=\"\(DiagramText.number(point.x))\" cy=\"\(DiagramText.number(point.y))\" r=\"8.5\" fill=\"\(DiagramTheme.line)\"/>"
            + DiagramText.centred(["\(number)"], at: point, fontSize: 10.5, bold: true, fill: "#ffffff")
    }

    private func note(_ lines: [String], x: Double, y: Double, width: Double, height: Double, font: Double) -> String {
        "<rect x=\"\(DiagramText.number(x))\" y=\"\(DiagramText.number(y))\" width=\"\(DiagramText.number(width))\" height=\"\(DiagramText.number(height))\" rx=\"3\" fill=\"\(DiagramTheme.noteFill)\" stroke=\"\(DiagramTheme.noteStroke)\" stroke-width=\"1.2\"/>"
            + DiagramText.centred(lines, at: CGPoint(x: x + width / 2, y: y + height / 2), fontSize: font)
    }

    private func frame(_ block: OpenBlock, left: Double, right: Double, bottom: Double, font: Double) -> String {
        func n(_ value: Double) -> String { DiagramText.number(value) }
        var markup = "<rect x=\"\(n(left))\" y=\"\(n(block.top))\" width=\"\(n(right - left))\" height=\"\(n(bottom - block.top))\" fill=\"none\" stroke=\"#8b9098\" stroke-width=\"1.3\"/>"
        let tabWidth = DiagramText.width(block.kind, size: 12, bold: true) + 20
        markup += "<path d=\"M\(n(left)),\(n(block.top)) h\(n(tabWidth)) v14 l-8,8 h\(n(-tabWidth + 8)) z\" fill=\"#eceef1\" stroke=\"#8b9098\" stroke-width=\"1.3\"/>"
        markup += DiagramText.centred([block.kind], at: CGPoint(x: left + tabWidth / 2 - 3, y: block.top + 11), fontSize: 12, bold: true)
        if !block.label.isEmpty {
            markup += DiagramText.centred(["[\(block.label)]"], at: CGPoint(x: left + tabWidth + 10, y: block.top + 11), fontSize: 12, fill: DiagramTheme.mutedText, anchor: "start")
        }
        for (position, label) in block.separators {
            markup += "<line x1=\"\(n(left))\" y1=\"\(n(position))\" x2=\"\(n(right))\" y2=\"\(n(position))\" stroke=\"#8b9098\" stroke-width=\"1.3\" stroke-dasharray=\"6 4\"/>"
            if !label.isEmpty {
                markup += DiagramText.centred(["[\(label)]"], at: CGPoint(x: left + 12, y: position + 13), fontSize: 12, fill: DiagramTheme.mutedText, anchor: "start")
            }
        }
        return markup
    }

    private func participantBox(_ participant: Participant, centerX: Double, top: Double, width: Double, height: Double) -> String {
        func n(_ value: Double) -> String { DiagramText.number(value) }
        let lines = DiagramText.lines(participant.label)
        if participant.isActor {
            // A small figure above its name.
            let cy = top + 9
            var markup = "<circle cx=\"\(n(centerX))\" cy=\"\(n(cy))\" r=\"5.5\" fill=\"#ffffff\" stroke=\"\(DiagramTheme.nodeStroke)\" stroke-width=\"1.6\"/>"
            markup += "<path d=\"M\(n(centerX)),\(n(cy + 5.5)) v10 M\(n(centerX - 8)),\(n(cy + 9)) h16 M\(n(centerX)),\(n(cy + 15.5)) l-7,9 M\(n(centerX)),\(n(cy + 15.5)) l7,9\" fill=\"none\" stroke=\"\(DiagramTheme.nodeStroke)\" stroke-width=\"1.6\" stroke-linecap=\"round\"/>"
            return markup + DiagramText.centred(lines, at: CGPoint(x: centerX, y: top + height + 12), fontSize: 13, bold: true)
        }
        return "<rect x=\"\(n(centerX - width / 2))\" y=\"\(n(top))\" width=\"\(n(width))\" height=\"\(n(height))\" rx=\"5\" fill=\"\(DiagramTheme.nodeFill)\" stroke=\"\(DiagramTheme.nodeStroke)\" stroke-width=\"1.5\"/>"
            + DiagramText.centred(lines, at: CGPoint(x: centerX, y: top + height / 2), fontSize: 14, bold: true)
    }
}
