//
//  DeletionRequest.swift
//  PolarBear
//

import Foundation

/// A file or folder the user asked to delete, waiting for confirmation.
struct DeletionRequest: Identifiable, Equatable {
    let path: String

    var id: String { path }

    var name: String {
        ProjectPath.name(of: path)
    }
}
