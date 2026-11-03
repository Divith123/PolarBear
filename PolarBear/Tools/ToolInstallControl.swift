//
//  ToolInstallControl.swift
//  PolarBear
//

import SwiftUI

/// The "Install Tectonic" / "Install OpenCode" control: a button, then a progress bar with Cancel,
/// then (if it went wrong) the reason and Try Again.
struct ToolInstallControl: View {
    @Environment(ProjectLibrary.self) private var library
    let tool: ManagedTool
    var isProminent = false

    var body: some View {
        switch library.installer.state(for: tool) {
        case .idle:
            installButton(title: "Install \(tool.displayName)")
        case .working(let step, let fraction):
            VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
                HStack(spacing: AppTheme.Spacing.m) {
                    if let fraction {
                        ProgressView(value: fraction)
                            .frame(maxWidth: 200)
                    } else {
                        ProgressView().controlSize(.small)
                    }
                    Button("Cancel") { library.installer.cancel(tool) }
                        .buttonStyle(.link)
                }
                Text(verbatim: step)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        case .failed(let message):
            VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
                Text(verbatim: message)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.danger)
                    .fixedSize(horizontal: false, vertical: true)
                installButton(title: "Try Again")
            }
        }
    }

    @ViewBuilder
    private func installButton(title: LocalizedStringKey) -> some View {
        let button = Button {
            library.install(tool)
        } label: {
            Label(title, systemImage: "arrow.down.circle")
        }
        .help("Downloads \(tool.displayName) from its official GitHub release (\(tool.downloadSize)) and installs it for PolarBear. Nothing is downloaded until you click.")

        if isProminent {
            button.buttonStyle(.borderedProminent).controlSize(.large)
        } else {
            button.buttonStyle(.bordered)
        }
    }
}
