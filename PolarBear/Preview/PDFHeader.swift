//
//  PDFHeader.swift
//  PolarBear
//

import SwiftUI

/// The preview's first row. On narrow panels it drops the pager and then the zoom title.
struct PDFHeader: View {
    let project: Project
    let preview: PreviewController
    @Binding var drawer: DrawerTab?
    let actions: PreviewActions

    var body: some View {
        ViewThatFits(in: .horizontal) {
            PDFHeaderRow(project: project, preview: preview, drawer: $drawer, actions: actions, showsPager: true, showsZoomTitle: true)
            PDFHeaderRow(project: project, preview: preview, drawer: $drawer, actions: actions, showsPager: false, showsZoomTitle: true)
            PDFHeaderRow(project: project, preview: preview, drawer: $drawer, actions: actions, showsPager: false, showsZoomTitle: false)
        }
    }
}
