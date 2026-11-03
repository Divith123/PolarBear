//
//  PDFPreviewSheet.swift
//  PolarBear
//

import SwiftUI

/// The preview as a sheet, for windows too narrow to dock it next to the editor.
struct PDFPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        WorkspacePreview()
            .frame(
                minWidth: AppTheme.Metrics.previewSheetWidth,
                minHeight: AppTheme.Metrics.previewSheetHeight
            )
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(AppTheme.Spacing.xl)
                    .background(AppTheme.appBackground)
            }
            .appAppearance()
    }
}
