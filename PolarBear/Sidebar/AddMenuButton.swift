//
//  AddMenuButton.swift
//  PolarBear
//

import SwiftUI

/// The "+" of the sidebar: new file, new folder, or copy files in.
struct AddMenuButton: View {
    let newFile: () -> Void
    let newFolder: () -> Void
    let addFiles: () -> Void

    var body: some View {
        Menu {
            Button("New File…", action: newFile)
            Button("New Folder…", action: newFolder)
            Divider()
            Button("Add Files…", action: addFiles)
        } label: {
            Image(systemName: "plus")
                .foregroundStyle(AppTheme.iconTertiary)
                .frame(width: AppTheme.Metrics.iconButton, height: AppTheme.Metrics.iconButton)
                .contentShape(.rect)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Add File or Folder")
        .help("Add File or Folder")
    }
}
