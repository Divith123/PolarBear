//
//  FixWithAIAction.swift
//  PolarBear
//

import Foundation

/// What "Fix with AI" can do right now.
struct FixWithAIAction {
    var hasProblems: Bool
    var isAvailable: Bool
    /// Shown when the button is disabled.
    var unavailableReason: String?
    var perform: () -> Void
}
