//
//  PDFTextView.swift
//  PolarBear
//

import PDFKit
import SwiftUI

/// The text of the PDF as plain, selectable text: for screen readers, and for copying.
struct PDFTextView: View {
    let url: URL
    @State private var text = ""

    var body: some View {
        ScrollView {
            Text(text.isEmpty ? String(localized: "This PDF has no text.") : text)
                .font(AppTheme.Typography.row)
                .foregroundStyle(AppTheme.textPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppTheme.Spacing.xxl)
        }
        .scrollIndicators(.hidden)
        .task(id: url) {
            text = PDFDocument(url: url)?.string ?? ""
        }
    }
}
