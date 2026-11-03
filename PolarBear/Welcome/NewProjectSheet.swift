//
//  NewProjectSheet.swift
//  PolarBear
//

import SwiftUI

/// Pick a template, name the project and choose where its folder goes.
struct NewProjectSheet: View {
    @Environment(WindowState.self) private var window
    @Environment(ProjectLibrary.self) private var library
    @Environment(\.dismiss) private var dismiss

    @State private var template = TemplateCatalog.article
    @State private var name = String(localized: "Untitled")
    @State private var location = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        ?? FileManager.default.homeDirectoryForCurrentUser

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xxl) {
            Text("New Project")
                .font(AppTheme.Typography.section)
                .foregroundStyle(AppTheme.textPrimary)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: AppTheme.Metrics.templateTileWidth), spacing: AppTheme.Spacing.l)],
                spacing: AppTheme.Spacing.l
            ) {
                ForEach(TemplateCatalog.all) { candidate in
                    TemplateTile(template: candidate, isSelected: candidate == template) { template = $0 }
                }
            }

            VStack(alignment: .leading, spacing: AppTheme.Spacing.m) {
                TextField("Project name", text: $name)
                    .textFieldStyle(.roundedBorder)

                HStack(spacing: AppTheme.Spacing.m) {
                    Text(location.path(percentEncoded: false))
                        .font(AppTheme.Typography.rowDetail)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 0)
                    Button("Choose Location…", action: chooseLocation)
                }
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Create", action: create)
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(AppTheme.Spacing.xxl)
        .frame(width: AppTheme.Metrics.sheetWidth)
        .background(AppTheme.appBackground)
        .appAppearance()
    }

    private func chooseLocation() {
        if let url = FilePanels.chooseFolder(
            message: String(localized: "Choose where to create the project folder."),
            prompt: String(localized: "Choose")
        ) {
            location = url
        }
    }

    private func create() {
        let template = template
        let name = name
        let location = location
        dismiss()
        Task {
            await window.createProject(name: name, template: template, in: location, library: library)
        }
    }
}

#Preview {
    NewProjectSheet()
        .environment(WindowState())
        .environment(ProjectLibrary())
}
