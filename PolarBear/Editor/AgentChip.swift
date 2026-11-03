//
//  AgentChip.swift
//  PolarBear
//

import SwiftUI

/// The composer's chip: "OpenCode · big-pickle · high". Clicking it opens the picker for the
/// agent, its model and its effort level.
struct AgentChip: View {
    let project: Project
    let catalog: AgentCatalog

    @State private var isPresented = false

    var body: some View {
        let current = catalog.effective(for: project)

        Button {
            isPresented.toggle()
        } label: {
            HStack(spacing: AppTheme.Spacing.s) {
                Text(verbatim: current.map(catalog.summary(for:)) ?? String(localized: "Set Up Assistant"))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Image(systemName: "chevron.up.chevron.down")
                    .imageScale(.small)
                    .accessibilityHidden(true)
            }
            .font(AppTheme.Typography.row)
            .foregroundStyle(AppTheme.iconTertiary)
            .frame(maxWidth: 240)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .fixedSize()
        .popover(isPresented: $isPresented, arrowEdge: .top) {
            AgentPickerPopover(project: project, catalog: catalog)
        }
        .accessibilityLabel("Agent, model and effort")
        .help("Agent, model and effort")
    }
}
