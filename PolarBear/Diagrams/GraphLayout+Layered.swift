//
//  GraphLayout+Layered.swift
//  PolarBear
//

import CoreGraphics
import Foundation

nonisolated extension GraphLayout {
    /// The layered layout, working top to bottom. See `GraphLayout.layout`.
    struct Layered {
        let nodes: [Node]
        let edges: [Edge]
        let nodeGap: Double
        let rankGap: Double

        private(set) var centers: [CGPoint] = []
        private(set) var routes: [Route] = []
        private(set) var size = CGSize.zero

        /// A real node or a point an edge passes through.
        private struct Item {
            var width: Double
            var height: Double
            var layer = 0
            var isDummy = false
            var sortKey = 0.0
            var x = 0.0
            var y = 0.0
        }

        private struct Chain {
            /// Item numbers from the upper end to the lower end.
            var items: [Int]
            var isReversed: Bool
            var labelItem: Int?
        }

        private var items: [Item] = []
        private var chains: [Chain?] = []
        private var layers: [[Int]] = []
        private var above: [[Int]] = []
        private var below: [[Int]] = []
        /// The place of each item inside its layer.
        private var slot: [Int] = []

        init(nodes: [Node], edges: [Edge], nodeGap: Double, rankGap: Double) {
            self.nodes = nodes
            self.edges = edges
            self.nodeGap = nodeGap
            self.rankGap = rankGap
        }

        // MARK: Steps

        mutating func run() {
            let reversed = findBackEdges()
            let rank = assignRanks(reversed: reversed)
            buildItems(rank: rank, reversed: reversed)
            orderLayers()
            placeLayers()
            collectResults()
        }

        /// Edges that close a cycle are laid out reversed.
        private func findBackEdges() -> [Bool] {
            let count = nodes.count
            var outgoing = Array(repeating: [Int](), count: count)
            for (index, edge) in edges.enumerated() where edge.from != edge.to { outgoing[edge.from].append(index) }

            var state = Array(repeating: 0, count: count) // 0 new, 1 on the stack, 2 done
            var reversed = Array(repeating: false, count: edges.count)
            for start in 0..<count where state[start] == 0 {
                var stack: [(node: Int, next: Int)] = [(start, 0)]
                state[start] = 1
                while !stack.isEmpty {
                    let (node, next) = stack[stack.count - 1]
                    if next < outgoing[node].count {
                        stack[stack.count - 1].next += 1
                        let edgeIndex = outgoing[node][next]
                        let target = edges[edgeIndex].to
                        if state[target] == 1 {
                            reversed[edgeIndex] = true
                        } else if state[target] == 0 {
                            state[target] = 1
                            stack.append((target, 0))
                        }
                    } else {
                        state[node] = 2
                        stack.removeLast()
                    }
                }
            }
            return reversed
        }

        /// Longest-path ranks, doubled so every edge has room for a label between its ends.
        private func assignRanks(reversed: [Bool]) -> [Int] {
            let count = nodes.count
            var successors = Array(repeating: [Int](), count: count)
            var indegree = Array(repeating: 0, count: count)
            for (index, edge) in edges.enumerated() where edge.from != edge.to {
                let (a, b) = reversed[index] ? (edge.to, edge.from) : (edge.from, edge.to)
                successors[a].append(b)
                indegree[b] += 1
            }
            var rank = Array(repeating: 0, count: count)
            var queue = (0..<count).filter { indegree[$0] == 0 }
            var head = 0
            let hasPredecessor = indegree.map { $0 > 0 }
            while head < queue.count {
                let node = queue[head]
                head += 1
                for target in successors[node] {
                    rank[target] = max(rank[target], rank[node] + 1)
                    indegree[target] -= 1
                    if indegree[target] == 0 { queue.append(target) }
                }
            }
            // A start node sits just above its nearest successor, not at the very top.
            for node in 0..<count where !hasPredecessor[node] && !successors[node].isEmpty {
                rank[node] = (successors[node].map { rank[$0] }.min() ?? 1) - 1
            }
            return rank.map { $0 * 2 }
        }

        private mutating func buildItems(rank: [Int], reversed: [Bool]) {
            items = nodes.enumerated().map { index, node in
                Item(width: node.size.width, height: node.size.height, layer: rank[index], sortKey: Double(index))
            }
            chains = Array(repeating: nil, count: edges.count)

            for (index, edge) in edges.enumerated() where edge.from != edge.to {
                let (upper, lower) = reversed[index] ? (edge.to, edge.from) : (edge.from, edge.to)
                var chainItems = [upper]
                let span = rank[lower] - rank[upper]
                let middle = span / 2
                var labelItem: Int?
                if span > 1 {
                    for step in 1..<span {
                        var dummy = Item(width: 10, height: 0, layer: rank[upper] + step, isDummy: true)
                        dummy.sortKey = (Double(upper) + Double(lower)) / 2 + Double(index) * 0.001
                        if step == middle, let label = edge.labelSize {
                            dummy.width = label.width + 10
                            dummy.height = label.height + 6
                            labelItem = items.count
                        }
                        chainItems.append(items.count)
                        items.append(dummy)
                    }
                }
                chainItems.append(lower)
                chains[index] = Chain(items: chainItems, isReversed: reversed[index], labelItem: labelItem)
            }

            let layerCount = (items.map(\.layer).max() ?? 0) + 1
            layers = Array(repeating: [], count: layerCount)
            for (index, item) in items.enumerated() { layers[item.layer].append(index) }
            for layer in layers.indices {
                layers[layer].sort { items[$0].sortKey < items[$1].sortKey }
            }

            above = Array(repeating: [], count: items.count)
            below = Array(repeating: [], count: items.count)
            for case let chain? in chains {
                for pair in zip(chain.items, chain.items.dropFirst()) {
                    below[pair.0].append(pair.1)
                    above[pair.1].append(pair.0)
                }
            }
        }

        // MARK: Ordering

        private mutating func orderLayers() {
            slot = Array(repeating: 0, count: items.count)
            for ids in layers { for (index, id) in ids.enumerated() { slot[id] = index } }
            guard layers.count > 1 else { return }
            // Big graphs get fewer passes so a huge diagram cannot stall the build.
            let sweeps = items.count > 3000 ? 2 : (items.count > 800 ? 6 : 14)
            for sweep in 0..<sweeps {
                if sweep.isMultiple(of: 2) {
                    for layer in 1..<layers.count { reorder(layer, using: above) }
                } else {
                    for layer in stride(from: layers.count - 2, through: 0, by: -1) { reorder(layer, using: below) }
                }
            }
        }

        private mutating func reorder(_ layer: Int, using neighbours: [[Int]]) {
            let current = layers[layer]
            var keyed: [(id: Int, key: Double, order: Int)] = []
            keyed.reserveCapacity(current.count)
            for (order, id) in current.enumerated() {
                let near = neighbours[id]
                let key = near.isEmpty ? Double(order) : Double(near.reduce(0) { $0 + slot[$1] }) / Double(near.count)
                keyed.append((id, key, order))
            }
            keyed.sort { $0.key == $1.key ? $0.order < $1.order : $0.key < $1.key }
            layers[layer] = keyed.map(\.id)
            for (index, id) in layers[layer].enumerated() { slot[id] = index }
        }

        // MARK: Placement

        private func gap(_ a: Item, _ b: Item) -> Double {
            if a.isDummy && b.isDummy { return 14 }
            if a.isDummy || b.isDummy { return nodeGap * 0.5 }
            return nodeGap
        }

        private mutating func placeLayers() {
            // Down the page.
            var y = 0.0
            var previousThickness = 0.0
            for (layer, ids) in layers.enumerated() {
                let thickness = ids.map { items[$0].height }.max() ?? 0
                y += layer == 0 ? thickness / 2 : previousThickness / 2 + rankGap / 2 + thickness / 2
                for id in ids { items[id].y = y }
                previousThickness = thickness
            }

            // Across the page: pack, then pull nodes toward their neighbours.
            for ids in layers {
                var x = 0.0
                for (index, id) in ids.enumerated() {
                    if index > 0 { x += (items[ids[index - 1]].width + items[id].width) / 2 + gap(items[ids[index - 1]], items[id]) }
                    items[id].x = x
                }
                let mid = ((ids.last.map { items[$0].x } ?? 0)) / 2
                for id in ids { items[id].x -= mid }
            }
            for round in 0..<(items.count > 3000 ? 2 : (items.count > 800 ? 6 : 12)) {
                let downward = round.isMultiple(of: 2)
                let order = downward ? Array(layers.indices) : Array(layers.indices.reversed())
                for layer in order {
                    let neighbours = downward ? above : below
                    relax(layer, using: neighbours)
                }
            }
        }

        /// Moves the nodes of one layer toward the average position of their neighbours without
        /// overlapping (an isotonic regression keeps the order and the minimum gaps).
        private mutating func relax(_ layer: Int, using neighbours: [[Int]]) {
            let ids = layers[layer]
            guard ids.count > 0 else { return }
            var desired: [Double] = []
            for id in ids {
                let near = neighbours[id].map { items[$0].x }
                desired.append(near.isEmpty ? items[id].x : near.reduce(0, +) / Double(near.count))
            }
            var offsets = [0.0]
            for index in 1..<max(ids.count, 1) where ids.count > 1 {
                let a = items[ids[index - 1]], b = items[ids[index]]
                offsets.append(offsets[index - 1] + (a.width + b.width) / 2 + gap(a, b))
            }

            // Pool adjacent violators on y = desired - offset.
            var blocks: [(sum: Double, count: Int)] = []
            for index in ids.indices {
                blocks.append((desired[index] - offsets[index], 1))
                while blocks.count > 1 {
                    let last = blocks[blocks.count - 1], previous = blocks[blocks.count - 2]
                    if previous.sum / Double(previous.count) <= last.sum / Double(last.count) { break }
                    blocks.removeLast(2)
                    blocks.append((previous.sum + last.sum, previous.count + last.count))
                }
            }
            var index = 0
            for block in blocks {
                let mean = block.sum / Double(block.count)
                for _ in 0..<block.count {
                    items[ids[index]].x = mean + offsets[index]
                    index += 1
                }
            }
        }

        // MARK: Results

        private mutating func collectResults() {
            var minX = Double.infinity, maxX = -Double.infinity, maxY = 0.0
            for item in items {
                minX = min(minX, item.x - item.width / 2)
                maxX = max(maxX, item.x + item.width / 2)
                maxY = max(maxY, item.y + item.height / 2)
            }
            let margin = 16.0
            let shift = margin - minX
            centers = (0..<nodes.count).map { CGPoint(x: items[$0].x + shift, y: items[$0].y + margin) }
            size = CGSize(width: maxX - minX + margin * 2, height: maxY + margin * 2)

            routes = edges.indices.map { index in
                let edge = edges[index]
                if edge.from == edge.to {
                    let center = centers[edge.from]
                    return Route(points: [center, center], labelPosition: nil)
                }
                guard let chain = chains[index] else { return Route(points: [], labelPosition: nil) }
                var points = chain.items.map { CGPoint(x: items[$0].x + shift, y: items[$0].y + margin) }
                if chain.isReversed { points.reverse() }
                let label = chain.labelItem.map { CGPoint(x: items[$0].x + shift, y: items[$0].y + margin) }
                return Route(points: points, labelPosition: label)
            }
        }
    }
}
