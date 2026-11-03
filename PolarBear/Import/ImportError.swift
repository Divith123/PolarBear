//
//  ImportError.swift
//  PolarBear
//

import Foundation

nonisolated enum ImportError: LocalizedError {
    case noLaTeX

    var errorDescription: String? {
        String(localized: "The archive contains no .tex files.")
    }
}
