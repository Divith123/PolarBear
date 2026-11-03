//
//  ConsentSheet.swift
//  PolarBear
//

import SwiftUI

/// Asked once per project and agent, before the first run.
struct ConsentSheet: View {
    let request: ConsentRequest
    let agent: AgentModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
            Label {
                Text("Let \(request.kind.displayName) work on this project?")
                    .font(AppTheme.Typography.section)
            } icon: {
                Image(systemName: "sparkles")
            }
            .foregroundStyle(AppTheme.textPrimary)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.m) {
                Text("PolarBear gives it a temporary copy of this project's text files (.tex, .bib and similar). It never sees secrets such as .env files or keys, and nothing changes in your project until you click Keep on a change.")
                Text(request.kind.privacyNote)
                    .foregroundStyle(AppTheme.warning)
            }
            .font(AppTheme.Typography.rowDetail)
            .foregroundStyle(AppTheme.textSecondary)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { agent.denyConsent() }
                    .keyboardShortcut(.cancelAction)
                Button("Allow and Run") { agent.grantConsent() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(AppTheme.Spacing.xxl)
        .frame(width: 480)
        .background(AppTheme.appBackground)
        .appAppearance()
    }
}
