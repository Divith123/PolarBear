//
//  DrawerTab.swift
//  PolarBear
//

import Foundation

/// The tabs of the drawer that slides in over the preview.
enum DrawerTab: String, CaseIterable, Identifiable {
    case problems
    case log
    case stats
    case history

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .problems: "Problems"
        case .log: "Logs"
        case .stats: "Project Info"
        case .history: "Versions"
        }
    }

    var symbol: String {
        switch self {
        case .problems: "exclamationmark.triangle"
        case .log: "terminal"
        case .stats: "chart.bar"
        case .history: "clock.arrow.circlepath"
        }
    }
}
