//
//  FilesEmptyState.swift
//  PolarBear
//

import SwiftUI

/// Shown over the file list when it has no rows: either the project has no files at all, or
/// the filter matches none.
struct FilesEmptyState: View {
    let projectHasFiles: Bool
    let query: String
    let createFile: () -> Void

    var body: some View {
        if projectHasFiles {
            ContentUnavailableView.search(text: query)
        } else {
            ContentUnavailableView {
                Label("No Files", systemImage: "doc")
            } actions: {
                Button("New File", action: createFile)
            }
        }
    }
}
