//
//  ToolchainCard.swift
//  PolarBear
//

import SwiftUI

/// Tells the user, before they open anything, whether PolarBear can compile on this Mac.
struct ToolchainCard: View {
    @Environment(ProjectLibrary.self) private var library

    var body: some View {
        let model = library.toolchain

        Group {
            if !model.hasSearched {
                Label {
                    Text("Looking for a TeX engine…")
                } icon: {
                    ProgressView().controlSize(.small)
                }
                .font(AppTheme.Typography.rowDetail)
                .foregroundStyle(AppTheme.textSecondary)
            } else if let engine = model.toolchain.automaticEngine {
                ready(engine, toolchain: model.toolchain)
            } else {
                missing
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task {
            if !model.hasSearched { await model.refresh() }
        }
    }

    private func ready(_ engine: TeXEngine, toolchain: TeXToolchain) -> some View {
        HStack(spacing: AppTheme.Spacing.m) {
            Circle()
                .fill(AppTheme.success)
                .frame(width: AppTheme.Metrics.statusDot, height: AppTheme.Metrics.statusDot)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text("Compiles with \(engine.displayName)")
                    .font(AppTheme.Typography.rowDetail)
                    .foregroundStyle(AppTheme.textPrimary)
                if let path = toolchain.executable(for: engine) {
                    Text(path.path(percentEncoded: false))
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
    }

    private var missing: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.l) {
            Label {
                Text("No TeX engine found")
                    .font(AppTheme.Typography.rowDetail.bold())
            } icon: {
                Image(systemName: "exclamationmark.triangle")
            }
            .foregroundStyle(AppTheme.danger)

            Text("PolarBear compiles with Tectonic — one small program that fetches the packages it needs the first time you compile — or with MacTeX. PolarBear can install Tectonic for you.")
                .font(AppTheme.Typography.rowDetail)
                .foregroundStyle(AppTheme.textSecondary)

            ToolInstallControl(tool: .tectonic, isProminent: true)

            HStack(spacing: AppTheme.Spacing.l) {
                if let url = URL(string: "https://tug.org/mactex/") {
                    Link("Get MacTeX instead", destination: url)
                }
                Button("Check Again") {
                    Task { await library.toolchain.refresh() }
                }
            }
            .buttonStyle(.link)
            .font(AppTheme.Typography.rowDetail)
        }
        .padding(AppTheme.Spacing.xl)
        .background(AppTheme.dangerFill, in: .rect(cornerRadius: AppTheme.Radius.control))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Radius.control, style: .continuous)
                .stroke(AppTheme.dangerStroke, lineWidth: 1)
        }
    }
}
