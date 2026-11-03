//
//  ComposerBar.swift
//  PolarBear
//

import SwiftUI

/// The "Ask anything" bar pinned to the bottom of the editor column. What it sends goes to the
/// agent the user chose; the conversation opens in a panel above it.
struct ComposerBar: View {
    @Environment(WorkspaceModel.self) private var workspace
    @Environment(ProjectLibrary.self) private var library
    @State private var prompt = ""

    var body: some View {
        let project = workspace.project
        let agent = project.agent
        let kind = library.agents.effective(for: project)
        let executable = kind.flatMap { library.agents.installed[$0] }

        VStack(spacing: AppTheme.Spacing.m) {
            if agent.isPanelVisible {
                TranscriptPanel(agent: agent, workspace: workspace)
            } else if agent.isRunning || agent.hasNews {
                ComposerStatusStrip(agent: agent)
            }

            HStack(spacing: AppTheme.Spacing.xl) {
                TextField(
                    "Ask anything",
                    text: $prompt,
                    prompt: Text(kind == nil ? "Set up the assistant to ask anything" : "Ask anything")
                        .foregroundStyle(AppTheme.textTertiary)
                )
                .textFieldStyle(.plain)
                .font(AppTheme.Typography.composer)
                .foregroundStyle(AppTheme.textPrimary)
                .focusEffectDisabled()
                .onSubmit { send(kind: kind, executable: executable) }

                ComposerPlusMenu(agent: agent, fix: workspace.fixWithAIAction(catalog: library.agents), send: { sendPreset($0, kind: kind, executable: executable) })

                if agent.currentSession != nil {
                    IconButton(
                        title: agent.isPanelVisible ? "Hide Conversation" : "Show Conversation",
                        systemImage: "bubble.left.and.bubble.right"
                    ) {
                        agent.isPanelVisible.toggle()
                    }
                }

                AgentChip(project: project, catalog: library.agents)

                if agent.isRunning {
                    Button("Stop", systemImage: "stop.fill") { agent.cancel() }
                        .buttonStyle(.send)
                } else {
                    Button("Send", systemImage: "arrow.up") { send(kind: kind, executable: executable) }
                        .buttonStyle(.send)
                        .disabled(kind == nil || prompt.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(.leading, AppTheme.Spacing.xxl)
            .padding(.trailing, AppTheme.Spacing.l)
            .frame(height: AppTheme.Metrics.composerHeight)
            .background(AppTheme.composerFill, in: .capsule)
            .overlay {
                Capsule().stroke(AppTheme.hairline, lineWidth: 1)
            }
        }
        .padding(.horizontal, AppTheme.Spacing.xl)
        .padding(.bottom, AppTheme.Spacing.l)
        .padding(.top, AppTheme.Spacing.xs)
        .sheet(item: Bindable(agent).consent) { request in
            ConsentSheet(request: request, agent: agent)
        }
    }

    private func send(kind: AgentKind?, executable: URL?) {
        guard let kind, let executable else { return }
        workspace.project.agent.send(prompt, with: kind, executable: executable, options: library.agents.options(for: kind))
        prompt = ""
    }

    private func sendPreset(_ text: String, kind: AgentKind?, executable: URL?) {
        guard let kind, let executable else { return }
        workspace.project.agent.send(text, with: kind, executable: executable, options: library.agents.options(for: kind))
    }
}
