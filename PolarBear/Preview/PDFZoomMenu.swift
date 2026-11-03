//
//  PDFZoomMenu.swift
//  PolarBear
//

import SwiftUI

struct PDFZoomMenu: View {
    let preview: PreviewController
    let showsTitle: Bool

    var body: some View {
        Menu {
            Button("Zoom to Fit") { preview.zoomToFit() }
            Divider()
            Button("Zoom In") { preview.zoomIn() }
            Button("Zoom Out") { preview.zoomOut() }
            Divider()
            ForEach(PDFZoom.presets, id: \.self) { value in
                Button("\(value)%") { preview.zoom = .percent(value) }
            }
        } label: {
            HStack(spacing: AppTheme.Spacing.m) {
                let zoomLabel = Label {
                    switch preview.zoom {
                    case .fit: Text("Zoom to fit")
                    case .percent(let value): Text("\(value)%")
                    }
                } icon: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .imageScale(.small)
                }

                if showsTitle {
                    zoomLabel
                        .labelStyle(.titleAndIcon)
                        .font(AppTheme.Typography.row)
                        .foregroundStyle(AppTheme.textPrimary)
                } else {
                    zoomLabel
                        .labelStyle(.iconOnly)
                        .foregroundStyle(AppTheme.textPrimary)
                }

                Image(systemName: "chevron.down")
                    .imageScale(.small)
                    .foregroundStyle(AppTheme.iconSecondary)
                    .accessibilityHidden(true)
            }
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Zoom")
    }
}
