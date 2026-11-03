//
//  PDFFloatingBar.swift
//  PolarBear
//

import SwiftUI

/// The pill that floats over the bottom of the preview: undo / redo for the editor, the
/// previous and next page, and "Go to PDF", which scrolls the PDF to the line being edited.
struct PDFFloatingBar: View {
    let preview: PreviewController
    let actions: PreviewActions

    var body: some View {
        HStack(spacing: AppTheme.Spacing.xl) {
            if let undo = actions.undo {
                barButton("Undo", systemImage: "arrow.counterclockwise", action: undo)
            }
            if let redo = actions.redo {
                barButton("Redo", systemImage: "arrow.clockwise", action: redo)
            }

            HStack(spacing: AppTheme.Spacing.m) {
                barButton("Previous Page", systemImage: "chevron.left", action: preview.previousPage)
                    .disabled(preview.pageIndex <= 0)

                Button {
                    actions.goToPDF?()
                } label: {
                    Text("Go to PDF")
                        .font(AppTheme.Typography.tab)
                        .foregroundStyle(AppTheme.textPrimary)
                }
                .buttonStyle(.plain)
                .disabled(actions.goToPDF == nil)

                barButton("Next Page", systemImage: "chevron.right", action: preview.nextPage)
                    .disabled(preview.pageIndex >= preview.pageCount - 1)
            }
        }
        .foregroundStyle(AppTheme.iconSecondary)
        .padding(.horizontal, AppTheme.Spacing.xxl)
        .frame(height: AppTheme.Metrics.floatingBarHeight)
        .background(AppTheme.floatingBarFill, in: .capsule)
        .overlay {
            Capsule().stroke(AppTheme.hairline, lineWidth: 1)
        }
    }

    private func barButton(_ title: LocalizedStringKey, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(title, systemImage: systemImage, action: action)
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .help(title)
    }
}
