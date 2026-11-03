//
//  DocumentStats.swift
//  PolarBear
//

import Foundation

/// Word and element counts of a document, in the spirit of `texcount`.
nonisolated struct DocumentStats: Equatable, Sendable {
    var wordsInText = 0
    var wordsInHeaders = 0
    /// Captions and similar text outside the running text.
    var wordsOutsideText = 0
    var headers = 0
    var figures = 0
    var inlineMath = 0
    var displayedMath = 0

    var words: Int {
        wordsInText + wordsInHeaders + wordsOutsideText
    }
}
