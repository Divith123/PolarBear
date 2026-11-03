//
//  ProjectPickerRow.swift
//  PolarBear
//

import SwiftUI

/// The project's name with its menu (switch project, rename, duplicate, export, engine…) and
/// the share button.
struct ProjectPickerRow: View {
    @Environment(WorkspaceModel.self) private var workspace
    @Environment(WindowState.self) private var window
    @Environment(ProjectLibrary.self) private var library
    @Environment(\.openWindow) private var openWindow

    @State private var isRenaming = false
    @State private var newName = ""
    @State private var isConfirmingTrash = false

    var body: some View {
        let project = workspace.project

        HStack(spacing: AppTheme.Spacing.m) {
            Menu {
                ProjectMenuContent(
                    project: project,
                    recents: library.recents.filter { $0.path != project.id },
                    open: openRecent,
                    rename: startRenaming,
                    duplicate: duplicate,
                    trash: { isConfirmingTrash = true }
                )
            } label: {
                HStack {
                    Text(project.name)
                        .font(AppTheme.Typography.row)
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: AppTheme.Spacing.xs)
                    Image(systemName: "chevron.down")
                        .imageScale(.small)
                        .foregroundStyle(AppTheme.iconPrimary)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, AppTheme.Spacing.l)
                .frame(height: AppTheme.Metrics.controlHeight)
                .background(AppTheme.controlFill, in: .rect(cornerRadius: AppTheme.Radius.control))
                .contentShape(.rect(cornerRadius: AppTheme.Radius.control))
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .accessibilityLabel("Project: \(project.name)")

            ShareMenuButton(workspace: workspace)
        }
        .alert("Rename Project", isPresented: $isRenaming) {
            TextField("Name", text: $newName)
            Button("Rename", action: rename)
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Move “\(project.name)” to Trash?", isPresented: $isConfirmingTrash) {
            Button("Move Project Folder to Trash", role: .destructive, action: trash)
        } message: {
            Text("The whole folder, including its history, goes to the Trash. You can restore it from there.")
        }
    }

    // MARK: Actions

    private func openRecent(_ recent: RecentProject) {
        Task { await window.open(recent, library: library) }
    }

    private func startRenaming() {
        newName = workspace.project.name
        isRenaming = true
    }

    private func rename() {
        let name = newName
        Task { await window.renameProject(to: name, library: library) }
    }

    private func duplicate() {
        Task {
            if let copy = await window.duplicateProject() {
                library.pendingOpen = copy
                openWindow(id: "main")
            }
        }
    }

    private func trash() {
        Task { await window.trashProject(library: library) }
    }
}
