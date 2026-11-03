//
//  SyncTeXIndex.swift
//  PolarBear
//

import Foundation

/// The contents of a `.synctex` file: for every page, the boxes and glue TeX placed and the
/// source file and line each came from. Coordinates are PDF points measured from the top-left
/// of the page. Parsing is in this file, the two searches in `SyncTeXIndex+Search`.
nonisolated struct SyncTeXIndex: Sendable {
    struct Node: Sendable {
        enum Kind: Sendable {
            case hbox
            case vbox
            case point
        }

        var kind: Kind
        var tag: Int
        var line: Int
        var x: Double
        var y: Double
        var width: Double
        var height: Double
        var depth: Double
        /// Index of the enclosing horizontal box on the same page.
        var parent: Int?
    }

    /// Input tag → absolute path of the file, as the engine saw it.
    var inputs: [Int: String] = [:]
    /// Nodes per page, in the order TeX emitted them (page 0 first).
    var pages: [[Node]] = []

    // MARK: Parsing

    static func parse(_ text: String) -> SyncTeXIndex {
        var index = SyncTeXIndex()
        var unit = 1.0
        var magnification = 1000.0
        var xOffset = 0.0
        var yOffset = 0.0
        var inContent = false
        var page = -1
        var open: [Int] = []

        func scale() -> Double {
            unit * (magnification / 1000) / 65536 * (72 / 72.27)
        }

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: true) {
            guard inContent else {
                if rawLine.hasPrefix("Input:") {
                    let parts = rawLine.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
                    if parts.count == 3, let tag = Int(parts[1]), !parts[2].isEmpty {
                        index.inputs[tag] = String(parts[2])
                    }
                } else if rawLine.hasPrefix("Magnification:") {
                    magnification = Double(rawLine.dropFirst("Magnification:".count)) ?? 1000
                } else if rawLine.hasPrefix("Unit:") {
                    unit = Double(rawLine.dropFirst("Unit:".count)) ?? 1
                } else if rawLine.hasPrefix("X Offset:") {
                    xOffset = Double(rawLine.dropFirst("X Offset:".count)) ?? 0
                } else if rawLine.hasPrefix("Y Offset:") {
                    yOffset = Double(rawLine.dropFirst("Y Offset:".count)) ?? 0
                } else if rawLine.hasPrefix("Content:") {
                    inContent = true
                }
                continue
            }
            if rawLine.hasPrefix("Postamble:") { break }

            guard let marker = rawLine.first else { continue }
            let body = rawLine.dropFirst()

            switch marker {
            case "{":
                page = (Int(body) ?? (page + 2)) - 1
                while index.pages.count <= page { index.pages.append([]) }
                open = []
            case "}":
                open = []
            case "]", ")":
                if !open.isEmpty { open.removeLast() }
            case "[", "(", "h", "v", "k", "g", "$", "x":
                guard page >= 0, let fields = parseFields(body) else { continue }
                let factor = scale()
                let isBox = marker == "[" || marker == "(" || marker == "h" || marker == "v"
                let kind: Node.Kind = (marker == "[" || marker == "v") ? .vbox : (isBox ? .hbox : .point)
                let node = Node(
                    kind: kind,
                    tag: fields.tag,
                    line: fields.line,
                    x: fields.x * factor + xOffset * factor,
                    y: fields.y * factor + yOffset * factor,
                    width: fields.width * factor,
                    height: fields.height * factor,
                    depth: fields.depth * factor,
                    parent: open.last(where: { index.pages[page][$0].kind == .hbox })
                )
                index.pages[page].append(node)
                if marker == "[" || marker == "(" { open.append(index.pages[page].count - 1) }
            default:
                continue
            }
        }
        return index
    }

    private struct Fields {
        var tag: Int
        var line: Int
        var x: Double
        var y: Double
        var width = 0.0
        var height = 0.0
        var depth = 0.0
    }

    /// `tag,line[,column]:x,y[:width,height,depth]`
    private static func parseFields(_ body: Substring) -> Fields? {
        let parts = body.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count >= 2 else { return nil }
        let source = parts[0].split(separator: ",")
        let position = parts[1].split(separator: ",")
        guard source.count >= 2, position.count >= 2,
              let tag = Int(source[0]), let line = Int(source[1]),
              let x = Double(position[0]), let y = Double(position[1]) else { return nil }

        var fields = Fields(tag: tag, line: line, x: x, y: y)
        if parts.count >= 3 {
            let size = parts[2].split(separator: ",")
            fields.width = size.indices.contains(0) ? Double(size[0]) ?? 0 : 0
            fields.height = size.indices.contains(1) ? Double(size[1]) ?? 0 : 0
            fields.depth = size.indices.contains(2) ? Double(size[2]) ?? 0 : 0
        }
        return fields
    }
}
