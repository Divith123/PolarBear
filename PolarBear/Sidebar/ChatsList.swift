//
//  ChatsList.swift
//  PolarBear
//

import SwiftUI

/// The sidebar's "Chats" tab: past conversations with agents, and a row to start a new one.
struct ChatsList: View {
    @Environment(WorkspaceModel.self) private var workspace

    var body: some View {
        let agent = workspace.project.agent

        VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
            Button {
                agent.newChat()
            } label: {
                Label("New Chat", systemImage: "square.and.pencil")
                    .font(AppTheme.Typography.row)
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.horizontal, AppTheme.Spacing.l)
                    .frame(maxWidth: .infinity, minHeight: AppTheme.Metrics.rowHeight, alignment: .leading)
            }
            .buttonStyle(.plain)
            .rowHighlight(isSelected: false)
            .padding(.top, AppTheme.Spacing.xl)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                    ForEach(agent.sessions) { session in
                        ChatRow(
                            session: session,
                            isActive: session.id == agent.currentID,
                            select: { agent.select($0.id) },
                            delete: agent.delete
                        )
                    }
                }
            }
            .scrollIndicators(.hidden)
            .overlay {
                if agent.sessions.isEmpty {
                    ContentUnavailableView {
                        Label {
                            Text("No Chats Yet")
                        } icon: {
                            PolarBearLogo(size: 40)
                        }
                    } description: {
                        Text("Ask your agent something below the editor.")
                    }
                }
            }
        }
    }
}
