//
//  ToolInstallState.swift
//  PolarBear
//

import Foundation

/// What the install button of a tool shows.
enum ToolInstallState: Equatable {
    case idle
    /// `fraction` is `nil` when the progress cannot be measured.
    case working(step: String, fraction: Double?)
    case failed(String)
}
