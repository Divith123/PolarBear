//
//  ProjectMenuContent.swift
//  PolarBear
//

import SwiftUI

/// The items of the project menu.
struct ProjectMenuContent: View {
    let project: Project
    let recents: [RecentProject]
    let open: (RecentProject) -> Void
    let rename: () -> Void
    let duplicate: () -> Void
    let trash: () -> Void

    @Environment(WorkspaceModel.self) private var workspace
    @Environment(WindowState.self) private var window
    @Environment(ProjectLibrary.self) private var library

    var body: some View {
        if !recents.isEmpty {
            Section("Recent Projects") {
                ForEach(recents.prefix(8)) { recent in
                    Button(recent.name) { open(recent) }
                }
            }
        }

        Button("Open Folder…") {
            Task { await window.openFolderFromPanel(library: library) }
        }
        Button("New Project…") { window.sheet = .newProject }

        Divider()

        Button("Show in Finder") { workspace.revealProjectInFinder() }
        Button("Rename Project…", action: rename)
        Button("Duplicate Project", action: duplicate)
        Button("Export Project as Zip…") { workspace.exportArchive() }

        Divider()

        EngineMenu(project: project)
        RealtimeToggle(project: project)
        RemoteImagesToggle(project: project)

        Divider()

        Button("Close Project") { window.closeProject() }
        Button("Move Project to Trash…", role: .destructive, action: trash)
    }
}
