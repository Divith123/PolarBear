//
//  WorkspaceCommands.swift
//  PolarBear
//

import SwiftUI

/// Menu commands. They act on the frontmost window through its focused `WindowState` and
/// `WorkspaceModel`.
struct WorkspaceCommands: Commands {
    let library: ProjectLibrary

    @FocusedValue(\.window) private var window
    @FocusedValue(\.workspace) private var workspace
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        fileCommands
        viewCommands
        compileCommands

        CommandMenu("Tabs") {
            Button("Next Tab") { workspace?.selectNextTab() }
                .keyboardShortcut("]", modifiers: [.command, .shift])
                .disabled(workspace == nil)
            Button("Previous Tab") { workspace?.selectPreviousTab() }
                .keyboardShortcut("[", modifiers: [.command, .shift])
                .disabled(workspace == nil)
        }
    }

    // MARK: File

    private var fileCommands: some Commands {
        Group {
            CommandGroup(replacing: .newItem) {
                Button("New Window") { openWindow(id: "main") }
                    .keyboardShortcut("n", modifiers: [.command, .option])
                Button("New Project…") { window?.sheet = .newProject }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                    .disabled(window == nil)
                Button("Open Folder…") { openFolder() }
                    .keyboardShortcut("o")
                    .disabled(window == nil)
                Menu("Open Recent") {
                    ForEach(library.recents.prefix(10)) { recent in
                        Button(recent.name) { open(recent) }
                    }
                }
                .disabled(library.recents.isEmpty || window == nil)
                Button("Migrate from Prism…") { importArchive() }
                    .disabled(window == nil)
                Divider()
                Button("New File…") { workspace?.promptNewFile() }
                    .keyboardShortcut("n")
                    .disabled(workspace == nil)
                Button("New Folder…") { workspace?.promptNewFolder() }
                    .disabled(workspace == nil)
            }

            CommandGroup(replacing: .saveItem) {
                Button("Save") { save() }
                    .keyboardShortcut("s")
                    .disabled(workspace == nil)
                Button("Close Tab") { workspace?.closeActive() }
                    .keyboardShortcut("w")
                    .disabled(workspace?.activeID == nil)
                Divider()
                Button("Export PDF…") { workspace?.exportPDF() }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                    .disabled(workspace?.project.build.publishedPDF == nil)
                if let markdown = workspace?.markdownActions {
                    Button("Download Markdown…", action: markdown.downloadMarkdown)
                    Menu("Copy Document As") {
                        ForEach(MarkdownCopyFormat.allCases) { format in
                            Button(String(localized: format.title)) { markdown.copy(format) }
                        }
                    }
                }
                Button("Export Project as Zip…") { workspace?.exportArchive() }
                    .disabled(workspace == nil)
                Button("Show in Finder") { workspace?.revealProjectInFinder() }
                    .disabled(workspace == nil)
                Divider()
                Button("Close Project") { window?.closeProject() }
                    .disabled(workspace == nil)
            }
        }
    }

    // MARK: View

    private var viewCommands: some Commands {
        Group {
            CommandGroup(after: .sidebar) {
                Button("Toggle Sidebar") { workspace?.toggleSidebar() }
                    .keyboardShortcut("b")
                    .disabled(workspace == nil)
                Divider()
                Button("Zoom to Fit") { workspace?.preview.zoomToFit() }
                    .keyboardShortcut("0")
                    .disabled(workspace == nil)
                Button("Zoom In") { workspace?.preview.zoomIn() }
                    .keyboardShortcut("+")
                    .disabled(workspace == nil)
                Button("Zoom Out") { workspace?.preview.zoomOut() }
                    .keyboardShortcut("-")
                    .disabled(workspace == nil)
                Divider()
                if let workspace {
                    LayoutToggles(workspace: workspace)
                    Divider()
                }
                ForEach(DrawerTab.allCases) { tab in
                    Button("Show \(String(localized: tab.title))") { workspace?.toggleDrawer(tab) }
                        .disabled(workspace == nil)
                }
            }
        }
    }

    // MARK: Compile

    private var compileCommands: some Commands {
        CommandMenu("Compile") {
            Button("Compile") { workspace?.project.compile() }
                .keyboardShortcut("r")
                .disabled(workspace == nil)
            Button("Stop") { workspace?.project.build.cancel() }
                .keyboardShortcut(".")
                .disabled(workspace?.project.build.isRunning != true)
            Divider()
            Button("Go to PDF") { workspace?.syncPDFToCaret() }
                .keyboardShortcut("j", modifiers: [.command, .option])
                .disabled(workspace?.project.settings.mode != .tex)
            Divider()
            if let workspace {
                EngineMenu(project: workspace.project)
                RealtimeToggle(project: workspace.project)
                RemoteImagesToggle(project: workspace.project)
            }
        }
    }

    // MARK: Actions

    private func openFolder() {
        guard let window else { return }
        Task { await window.openFolderFromPanel(library: library) }
    }

    private func open(_ recent: RecentProject) {
        guard let window else { return }
        Task { await window.open(recent, library: library) }
    }

    private func importArchive() {
        guard let window,
              let url = FilePanels.chooseArchive(message: String(localized: "Choose a project archive (.zip or .tar.gz).")) else { return }
        window.sheet = .importProject(url)
    }

    private func save() {
        guard let project = workspace?.project else { return }
        Task { await project.saveVersion() }
    }
}
