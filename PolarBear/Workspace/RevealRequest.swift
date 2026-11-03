//
//  RevealRequest.swift
//  PolarBear
//

import Foundation

/// Asks the editor to jump to a line (used by the outline). Each request is unique, so
/// asking for the same line twice still scrolls twice.
struct RevealRequest: Equatable {
    let fileID: ProjectFile.ID
    let line: Int
    let token = UUID()
}
