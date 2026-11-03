//
//  ImportSheet.swift
//  PolarBear
//

import SwiftUI

/// Shows what an archive contains and imports it as a new project folder.
struct ImportSheet: View {
    let archive: URL

    @Environment(WindowState.self) private var window
    @Environment(ProjectLibrary.self) private var library
    @Environment(\.dismiss) private var dismiss

    @State private var phase = Phase.loading
    @State private var name = ""
    @State private var location = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        ?? FileManager.default.homeDirectoryForCurrentUser

    private enum Phase {
        case loading
        case ready(ImportPreview)
        case failed(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xxl) {
            Text("Migrate from Prism")
                .font(AppTheme.Typography.section)
                .foregroundStyle(AppTheme.textPrimary)

            switch phase {
            case .loading:
                Label {
                    Text("Reading “\(archive.lastPathComponent)”…")
                } icon: {
                    ProgressView().controlSize(.small)
                }
                .foregroundStyle(AppTheme.textSecondary)
            case .ready(let preview):
                ImportSummary(preview: preview, name: $name, location: $location)
            case .failed(let message):
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(AppTheme.danger)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: cancel)
                    .keyboardShortcut(.cancelAction)
                if case .ready(let preview) = phase {
                    Button("Import") { finish(preview) }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(AppTheme.Spacing.xxl)
        .frame(width: AppTheme.Metrics.sheetWidth)
        .background(AppTheme.appBackground)
        .appAppearance()
        .task { await load() }
    }

    private func load() async {
        if !library.toolchain.hasSearched { await library.toolchain.refresh() }
        do {
            let preview = try await ProjectImporter.prepare(archive: archive, toolchain: library.toolchain.toolchain)
            name = preview.suggestedName
            phase = .ready(preview)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func cancel() {
        if case .ready(let preview) = phase {
            Task { await ProjectImporter.discard(preview) }
        }
        dismiss()
    }

    private func finish(_ preview: ImportPreview) {
        let name = name
        let location = location
        dismiss()
        Task {
            do {
                let folder = try await ProjectImporter.finish(preview, name: name, in: location)
                await window.open(folder, library: library)
                window.workspace?.project.compile()
            } catch {
                window.report(error, title: "Can’t Import Project")
            }
        }
    }
}
