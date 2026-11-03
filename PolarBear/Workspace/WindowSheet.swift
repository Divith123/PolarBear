//
//  WindowSheet.swift
//  PolarBear
//

import Foundation

/// A sheet the window can present over the workspace or the welcome screen.
enum WindowSheet: Identifiable {
    case newProject
    case importProject(URL)

    var id: String {
        switch self {
        case .newProject: "new-project"
        case .importProject(let url): "import:\(url.path(percentEncoded: false))"
        }
    }
}
