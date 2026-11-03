//
//  AssetRow.swift
//  PolarBear
//

import SwiftUI

/// A file the code editor cannot show (an image, a PDF…). Double-click opens it in its own app.
struct AssetRow: View {
    let path: String
    let depth: Int
    let detail: String?
    let actions: FileRowActions

    var body: some View {
        Button {
            actions.openExternally(path)
        } label: {
            HStack(spacing: AppTheme.Spacing.xxs) {
                Image(systemName: symbol)
                    .imageScale(.small)
                    .foregroundStyle(AppTheme.iconTertiary)
                    .frame(width: AppTheme.Metrics.treeIndent)
                    .accessibilityHidden(true)
                Text(ProjectPath.name(of: path))
                    .font(AppTheme.Typography.row)
                    .foregroundStyle(AppTheme.textTertiary)
                    .lineLimit(1)
            }
            .padding(.leading, AppTheme.Metrics.treeGutter + Double(depth) * AppTheme.Metrics.treeIndent)
            .frame(maxWidth: .infinity, minHeight: AppTheme.Metrics.rowHeight, alignment: .leading)
        }
        .buttonStyle(.plain)
        .rowHighlight(isSelected: false)
        .contextMenu {
            Button("Open") { actions.openExternally(path) }
            Button("Show in Finder") { actions.reveal(path) }
            Divider()
            Button("Move to Trash", role: .destructive) { actions.delete(path) }
        }
    }

    private var symbol: String {
        switch FileKind(path: path) {
        case .image: "photo"
        case .pdf: "doc.richtext"
        default: "doc"
        }
    }
}
