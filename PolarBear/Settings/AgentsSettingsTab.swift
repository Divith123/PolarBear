//
//  AgentsSettingsTab.swift
//  PolarBear
//

import SwiftUI

/// Which agents PolarBear found, which one to use, and where each sends the text.
struct AgentsSettingsTab: View {
    @Environment(ProjectLibrary.self) private var library

    var body: some View {
        @Bindable var agents = library.agents

        Form {
            Section {
                Picker("Default Agent", selection: $agents.preferred) {
                    Text("Automatic").tag(AgentKind?.none)
                    ForEach(AgentKind.allCases) { kind in
                        Text(verbatim: kind.displayName).tag(AgentKind?.some(kind))
                    }
                }
            }

            Section("Found on This Mac") {
                ForEach(AgentKind.allCases) { kind in
                    AgentSettingsRow(kind: kind, url: agents.installed[kind], catalog: agents)
                }
                Button("Check Again") {
                    Task { await agents.refresh() }
                }
            }

            Section {
                Text("PolarBear does not provide AI itself. It starts the agent program you installed and signed in to, in a temporary copy of your project, and shows you every change before it touches your files.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
        }
        .formStyle(.grouped)
        .task {
            if !agents.hasSearched { await agents.refresh() }
        }
    }
}
