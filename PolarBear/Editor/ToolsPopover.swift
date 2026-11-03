//
//  ToolsPopover.swift
//  PolarBear
//

import SwiftUI

/// Which TeX programs PolarBear found, and where.
struct ToolsPopover: View {
    @Environment(ProjectLibrary.self) private var library

    var body: some View {
        let toolchain = library.toolchain.toolchain

        VStack(alignment: .leading, spacing: AppTheme.Spacing.m) {
            Text("TeX Programs")
                .font(AppTheme.Typography.section)
                .foregroundStyle(AppTheme.textPrimary)

            ToolRow(name: "PolarBear Engine", url: toolchain.polarbear)
            ToolRow(name: "latexmk", url: toolchain.latexmk)
            ToolRow(name: "pdfLaTeX", url: toolchain.pdflatex)
            ToolRow(name: "XeLaTeX", url: toolchain.xelatex)
            ToolRow(name: "LuaLaTeX", url: toolchain.lualatex)
            ToolRow(name: "Tectonic", url: toolchain.tectonic)
            if toolchain.tectonic == nil, !toolchain.hasTeXDistribution {
                ToolInstallControl(tool: .tectonic)
            }
            ToolRow(name: "synctex", url: toolchain.synctex)

            HStack {
                Button("Check Again") {
                    Task { await library.toolchain.refresh() }
                }
                Spacer()
                SettingsLink {
                    Text("Settings…")
                }
            }
            .font(AppTheme.Typography.rowDetail)
        }
        .padding(AppTheme.Spacing.xl)
        .frame(width: 340)
        .background(AppTheme.appBackground)
        .appAppearance()
    }
}
