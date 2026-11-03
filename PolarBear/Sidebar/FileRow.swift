//
//  FileRow.swift
//  PolarBear
//

import SwiftUI

/// A text file of the project in the sidebar tree.
struct FileRow: View {
    let file: ProjectFile
    let depth: Int
    let detail: String?
    let isActive: Bool
    let actions: FileRowActions

    var body: some View {
        Button {
            actions.open(file)
        } label: {
            HStack(spacing: AppTheme.Spacing.s) {
                Text(file.name)
                    .font(AppTheme.Typography.row)
                    .foregroundStyle(isActive ? AppTheme.iconPrimary : AppTheme.textSecondary)
                    .lineLimit(1)
                if let detail {
                    Text(detail)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
                Spacer(minLength: 0)
                if file.conflict != nil {
                    Image(systemName: "exclamationmark.arrow.triangle.2.circlepath")
                        .imageScale(.small)
                        .foregroundStyle(AppTheme.warning)
                        .help("Changed on disk")
                }
            }
            .padding(.leading, AppTheme.Metrics.treeTextInset + Double(depth) * AppTheme.Metrics.treeIndent)
            .padding(.trailing, AppTheme.Spacing.m)
            .frame(maxWidth: .infinity, minHeight: AppTheme.Metrics.rowHeight, alignment: .leading)
        }
        .buttonStyle(.plain)
        .rowHighlight(isSelected: isActive)
        .accessibilityAddTraits(isActive ? .isSelected : [])
        .contextMenu {
            Button("Open") { actions.open(file) }
            Button("Rename…") { actions.rename(file.path) }
            Button("Duplicate") { actions.duplicate(file) }
            Divider()
            Button("Show in Finder") { actions.reveal(file.path) }
            Divider()
            Button("Move to Trash", role: .destructive) { actions.delete(file.path) }
        }
    }
}
