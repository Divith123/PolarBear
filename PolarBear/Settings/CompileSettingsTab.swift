//
//  CompileSettingsTab.swift
//  PolarBear
//

import SwiftUI

struct CompileSettingsTab: View {
    @Environment(ProjectLibrary.self) private var library

    var body: some View {
        let toolchain = library.toolchain.toolchain

        Form {
            Section("PolarBear Engine") {
                ToolRow(name: "PolarBear Engine", url: toolchain.polarbear)
                PolarBearEngineNote(
                    isBuilt: toolchain.polarbear != nil,
                    typesets: toolchain.polarbearTypesets,
                    version: toolchain.polarbearVersion,
                    isBundled: toolchain.polarbearIsBundled
                )
            }

            Section("TeX Programs") {
                ToolRow(name: "latexmk", url: toolchain.latexmk)
                ToolRow(name: "pdfLaTeX", url: toolchain.pdflatex)
                ToolRow(name: "XeLaTeX", url: toolchain.xelatex)
                ToolRow(name: "LuaLaTeX", url: toolchain.lualatex)
                ToolRow(name: "BibTeX", url: toolchain.bibtex)
                ToolRow(name: "Tectonic", url: toolchain.tectonic)
                ManagedToolActions(tool: .tectonic, url: toolchain.tectonic)
                ToolRow(name: "synctex", url: toolchain.synctex)
                ToolRow(name: "kpsewhich", url: toolchain.kpsewhich)
                Button("Check Again") {
                    Task { await library.toolchain.refresh() }
                }
            }

            Section("How PolarBear Chooses") {
                Text("A project’s engine is the one you pick in its menu. “Automatic” uses the PolarBear Engine as soon as it can typeset, then follows a % !TEX program = comment in the main file, and otherwise uses pdfLaTeX when a TeX distribution is installed, or Tectonic when it is not.")
                Text("Tectonic downloads the packages a document needs the first time it compiles, so that first build can take a minute. Later builds are fast.")
            }
            .foregroundStyle(.secondary)
            .font(.callout)
        }
        .formStyle(.grouped)
        .task {
            if !library.toolchain.hasSearched { await library.toolchain.refresh() }
        }
    }
}
