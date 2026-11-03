//
//  AgentPickerPopover.swift
//  PolarBear
//

import SwiftUI

/// Everything about who answers: the CLI, its model and the effort level.
struct AgentPickerPopover: View {
    @Bindable var project: Project
    let catalog: AgentCatalog

    var body: some View {
        let current = catalog.effective(for: project)

        VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                sectionTitle("Agent")
                ForEach(AgentKind.allCases) { kind in
                    AgentChoiceRow(
                        kind: kind,
                        isInstalled: catalog.installed[kind] != nil,
                        isSelected: current == kind
                    ) {
                        project.settings.selectedAgent = kind.rawValue
                    }
                }
            }

            if let current {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.m) {
                    sectionTitle("Model")
                    AgentModelMenu(kind: current, catalog: catalog)
                }
                VStack(alignment: .leading, spacing: AppTheme.Spacing.m) {
                    sectionTitle("Effort")
                    AgentEffortChips(kind: current, catalog: catalog)
                }
                Text(current.privacyNote)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.textTertiary)
            } else {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.l) {
                    Text("PolarBear can install OpenCode for you, or you can install another agent yourself and choose it here. PolarBear starts the agent for you; it never sees your login.")
                        .font(AppTheme.Typography.rowDetail)
                        .foregroundStyle(AppTheme.textSecondary)
                    ToolInstallControl(tool: .openCode, isProminent: true)
                }
            }

            HStack {
                Button("Check Again") {
                    Task { await catalog.refresh() }
                }
                Spacer()
                SettingsLink {
                    Text("Agent Settings…")
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.link)
            .font(AppTheme.Typography.rowDetail)
        }
        .padding(AppTheme.Spacing.xl)
        .frame(width: 360)
        .background(AppTheme.appBackground)
        .appAppearance()
    }

    private func sectionTitle(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(AppTheme.Typography.caption.bold())
            .foregroundStyle(AppTheme.textTertiary)
            .textCase(.uppercase)
    }
}
