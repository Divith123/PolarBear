//
//  FolderRow.swift
//  PolarBear
//

import SwiftUI

struct FolderRow: View {
    let path: String
    let depth: Int
    let isExpanded: Bool
    let actions: FileRowActions

    var body: some View {
        Button {
            actions.toggleFolder(path)
        } label: {
            HStack(spacing: AppTheme.Spacing.xxs) {
                Image(systemName: "chevron.right")
                    .imageScale(.small)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .foregroundStyle(AppTheme.iconTertiary)
                    .frame(width: AppTheme.Metrics.treeIndent)
                    .accessibilityHidden(true)
                Text(ProjectPath.name(of: path))
                    .font(AppTheme.Typography.row)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
            }
            .padding(.leading, AppTheme.Metrics.treeGutter + Double(depth) * AppTheme.Metrics.treeIndent)
            .frame(maxWidth: .infinity, minHeight: AppTheme.Metrics.rowHeight, alignment: .leading)
        }
        .buttonStyle(.plain)
        .rowHighlight(isSelected: false)
        .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
        .contextMenu {
            Button("New File Here…") { actions.newFile(path) }
            Button("New Folder Here…") { actions.newFolder(path) }
            Button("Add Files…") { actions.addFiles(path) }
            Divider()
            Button("Rename…") { actions.rename(path) }
            Button("Show in Finder") { actions.reveal(path) }
            Divider()
            Button("Move to Trash", role: .destructive) { actions.delete(path) }
        }
    }
}
