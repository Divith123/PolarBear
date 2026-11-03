//
//  AgentSettingsRow.swift
//  PolarBear
//

import SwiftUI

/// One agent: found with its path, or not found with the command that installs it.
struct AgentSettingsRow: View {
    let kind: AgentKind
    let url: URL?
    let catalog: AgentCatalog

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: url == nil ? "minus.circle" : "checkmark.circle.fill")
                    .foregroundStyle(url == nil ? Color.secondary : AppTheme.success)
                    .accessibilityHidden(true)
                Text(verbatim: kind.displayName)
                Spacer()
                if let url {
                    Text(url.path(percentEncoded: false))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else if kind != .openCode {
                    Text(verbatim: kind.installHint)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            Text(kind.privacyNote)
                .font(.caption)
                .foregroundStyle(.secondary)
            if kind == .openCode {
                ManagedToolActions(tool: .openCode, url: url)
                    .padding(.top, 2)
            }
            if url != nil {
                HStack(spacing: 12) {
                    AgentModelMenu(kind: kind, catalog: catalog)
                    AgentEffortChips(kind: kind, catalog: catalog)
                }
                .padding(.top, 4)
            }
        }
    }
}
