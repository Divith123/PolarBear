//
//  WindowSheetContent.swift
//  PolarBear
//

import SwiftUI

/// Chooses the view for the sheet a window is showing.
struct WindowSheetContent: View {
    let sheet: WindowSheet

    var body: some View {
        switch sheet {
        case .newProject:
            NewProjectSheet()
        case .importProject(let url):
            ImportSheet(archive: url)
        }
    }
}
