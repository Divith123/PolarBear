//
//  FlowGraph.swift
//  PolarBear
//

import CoreGraphics
import Foundation

/// The shared model of flowcharts and state diagrams.
nonisolated struct FlowGraph: Sendable {
    enum Shape: Sendable {
        case rectangle, rounded, stadium, subroutine, cylinder, circle, doubleCircle, diamond, hexagon
        case parallelogram, parallelogramAlt, trapezoid, trapezoidAlt, asymmetric
        case startDot, endDot, bar
    }

    struct Node: Sendable {
        var id: String
        var label: String
        var shape = Shape.rectangle
        var className: String?
        var style: [String: String] = [:]
    }

    enum LineStyle: Sendable { case solid, dotted, thick, invisible }
    enum Ending: Sendable { case none, arrow, circle, cross }

    struct Edge: Sendable {
        var from: String
        var to: String
        var label: String?
        var style = LineStyle.solid
        var head = Ending.arrow
        var tail = Ending.none
    }

    struct Subgraph: Sendable {
        var id: String
        var title: String
        var parent: String?
        var members: [String] = []
    }

    var direction = GraphLayout.Direction.topDown
    var nodes: [Node] = []
    var edges: [Edge] = []
    var subgraphs: [Subgraph] = []
    var classes: [String: [String: String]] = [:]
    private var indexByID: [String: Int] = [:]

    func index(of id: String) -> Int? { indexByID[id] }

    /// Adds a node, or updates the label and shape of an existing one when they are given explicitly.
    @discardableResult
    mutating func addNode(id: String, label: String? = nil, shape: Shape? = nil) -> Int {
        if let existing = indexByID[id] {
            if let label { nodes[existing].label = label }
            if let shape { nodes[existing].shape = shape }
            return existing
        }
        nodes.append(Node(id: id, label: label ?? id, shape: shape ?? .rectangle))
        indexByID[id] = nodes.count - 1
        return nodes.count - 1
    }
}
