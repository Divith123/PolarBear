//
//  ToolsBadge.swift
//  PolarBear
//

import SwiftUI

/// The "Tools" chip of the tab bar. It turns red when PolarBear cannot compile on this Mac, and
/// opens a list of the programs it found.
struct ToolsBadge: View {
    @Environment(ProjectLibrary.self) private var library
    @State private var isPresented = false

    var body: some View {
        let toolchain = library.toolchain
        let isMissing = toolchain.hasSearched && toolchain.toolchain.automaticEngine == nil

        Button {
            isPresented.toggle()
        } label: {
            Label {
                Text("Tools", comment: "Chip in the editor's tab bar that lists the installed TeX programs.")
            } icon: {
                Image(systemName: isMissing ? "exclamationmark.triangle" : "wrench.and.screwdriver")
            }
            .labelStyle(.trailingIcon)
            .font(AppTheme.Typography.row)
            .foregroundStyle(isMissing ? AppTheme.danger : AppTheme.textSecondary)
            .padding(.horizontal, AppTheme.Spacing.l)
            .frame(height: AppTheme.Metrics.chipHeight)
            .background(isMissing ? AppTheme.dangerFill : AppTheme.controlFill, in: .rect(cornerRadius: AppTheme.Radius.control))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Radius.control, style: .continuous)
                    .stroke(isMissing ? AppTheme.dangerStroke : AppTheme.hairline, lineWidth: 1)
            }
            .contentShape(.rect(cornerRadius: AppTheme.Radius.control))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            ToolsPopover()
                .environment(library)
        }
        .accessibilityLabel("Tools")
    }
}
