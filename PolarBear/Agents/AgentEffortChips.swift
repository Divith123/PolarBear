//
//  AgentEffortChips.swift
//  PolarBear
//

import SwiftUI

/// Choose how hard the model should think. The levels are the ones the CLI (and, for OpenCode,
/// the chosen model) accepts; when there are none, the row says why.
struct AgentEffortChips: View {
    let kind: AgentKind
    let catalog: AgentCatalog

    var body: some View {
        let levels = catalog.efforts(for: kind)
        let chosen = catalog.options(for: kind).effort

        if levels.isEmpty {
            Text(note)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 62), spacing: AppTheme.Spacing.s)], alignment: .leading, spacing: AppTheme.Spacing.s) {
                EffortChip(title: "Default", isSelected: chosen == nil) { catalog.setEffort(nil, for: kind) }
                ForEach(levels, id: \.self) { level in
                    EffortChip(title: LocalizedStringKey(level), isSelected: chosen == level) {
                        catalog.setEffort(level, for: kind)
                    }
                }
            }
        }
    }

    private var note: LocalizedStringKey {
        switch kind {
        case .gemini: "Gemini CLI has no effort setting."
        case .openCode:
            catalog.options(for: kind).model == nil
                ? "Choose a model to see its effort levels."
                : "This model has no effort levels."
        default: "No effort levels."
        }
    }
}
