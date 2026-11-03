//
//  PDFContent.swift
//  PolarBear
//

import SwiftUI

/// The area under the header: the PDF, its text, or a message saying why there is none.
struct PDFContent: View {
    let project: Project
    let preview: PreviewController
    @Binding var drawer: DrawerTab?
    let actions: PreviewActions

    var body: some View {
        let build = project.build

        ZStack {
            if let url = build.publishedPDF {
                if preview.isTextMode {
                    PDFTextView(url: url)
                } else {
                    PDFKitView(
                        url: url,
                        generation: build.publishedGeneration,
                        preview: preview,
                        onCommandClick: { page, point in actions.jumpToSource?(page, point) }
                    )
                }
            } else {
                PDFEmptyState(project: project, drawer: $drawer)
            }
        }
        .overlay(alignment: .top) {
            if build.isStale, build.publishedPDF != nil {
                StaleBanner(errorCount: build.errorCount, fix: actions.fixWithAI) { drawer = .problems }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
