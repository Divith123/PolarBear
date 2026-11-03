//
//  TabItem.swift
//  PolarBear
//

import SwiftUI

struct TabItem: View {
    let file: ProjectFile
    let isActive: Bool
    let activate: (ProjectFile.ID) -> Void
    let close: (ProjectFile.ID) -> Void
    let rename: (ProjectFile) -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: AppTheme.Spacing.xs) {
            Button {
                activate(file.id)
            } label: {
                Label {
                    Text(file.name)
                        .font(AppTheme.Typography.tab)
                        .lineLimit(1)
                        .fixedSize()
                } icon: {
                    Image(systemName: "doc")
                        .imageScale(.small)
                }
                .foregroundStyle(isActive ? AppTheme.textPrimary : AppTheme.textSecondary)
                .padding(.leading, AppTheme.Spacing.xl)
                .frame(maxHeight: .infinity)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            Button("Close Tab", systemImage: file.isDirty && !isHovering ? "circle.fill" : "xmark") {
                close(file.id)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .imageScale(.small)
            .foregroundStyle(AppTheme.textSecondary)
            .frame(width: AppTheme.Metrics.closeButton, height: AppTheme.Metrics.closeButton)
            .contentShape(.rect)
            .opacity(isActive || isHovering || file.isDirty ? 1 : 0)
            .padding(.trailing, AppTheme.Spacing.s)
            .accessibilityLabel("Close Tab")
            .help("Close Tab")
        }
        .frame(height: AppTheme.Metrics.tabHeight)
        .background(fill, in: .rect(cornerRadius: AppTheme.Radius.control))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Radius.control, style: .continuous)
                .stroke(isActive ? AppTheme.tabBorder : .clear, lineWidth: 1)
        }
        .onHover { isHovering = $0 }
        .accessibilityAddTraits(isActive ? .isSelected : [])
        .contextMenu {
            Button("Close Tab") { close(file.id) }
            Button("Rename…") { rename(file) }
        }
    }

    private var fill: Color {
        if isActive {
            AppTheme.tabFill
        } else if isHovering {
            AppTheme.tabHoverFill
        } else {
            .clear
        }
    }
}
