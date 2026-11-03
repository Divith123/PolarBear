//
//  EditorViewState.swift
//  PolarBear
//

import Foundation

/// Caret and scroll position of a file whose editor view was released to save memory.
struct EditorViewState: Equatable {
    var selection: NSRange
    var scrollY: Double
}
