//
//  MarkdownExportItems.swift
//  PolarBear
//

import SwiftUI

/// The download and copy commands of a Markdown project, as menu items.
struct MarkdownExportItems: View {
    let actions: MarkdownActions
    let hasPDF: Bool

    var body: some View {
        Button("Download Markdown…", systemImage: "arrow.down.doc", action: actions.downloadMarkdown)
        Button("Download PDF…", systemImage: "arrow.down.circle", action: actions.downloadPDF)
            .disabled(!hasPDF)

        Divider()

        ForEach(MarkdownCopyFormat.allCases) { format in
            Button {
                actions.copy(format)
            } label: {
                Label(String(localized: format.title), systemImage: format.symbol)
            }
        }
    }
}
